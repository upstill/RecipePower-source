class CollectibleServices

  attr_accessor :entity

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :entity

  def initialize entity
    self.entity = entity
  end

  # Return the list of users who have collected this entity
  def collectors
    Rcpref.where(entity: entity, private: false, in_collection: true).includes(:user).map &:user
  end

  # Either fetch an existing recipe record or make a new one, based on the
  # params. If the params have an :id, we find on that, otherwise we look
  # for a record matching the :url. If there are no params, just return a new recipe
  # If a new recipe record needs to be created, we also do QA on the provided URL
  # and dig around for a title, description, etc.
  # Either way, we also make sure that the recipe is associated with the given user
  def self.find_or_create params, extractions = nil, klass = Recipe
    if extractions.is_a? Class
      extractions, klass = nil, extractions
    end
    if params[:id]
      # Recipe (or whatever) exists and we're just touching it for the user
      entity = klass.find params[:id]
    elsif !(entity = RecipeReference.lookup_recipe params[:url])
    # TODO elsif !(entity = RecipePageRef.recipe params[:url])
      # Get findings, either from the extractions, or by looking at the page
      unless findings = FinderServices.findings(extractions, params[:url])
        entity = klass.new params
        entity.errors[:url] = 'Doesn\'t appear to be a working URL: we can\'t open it for analysis'
        return entity
      end
      # Extractions are parameters derived directly from the page
      url = findings.result_for('URI') || findings.result_for('href') || params[:url]
      uri = URI url
      if uri.blank?
        entity = klass.new
      elsif (id = params[:id].to_i) && (id > 0) # id of 0 means create a new recipe
        begin
          entity = klass.find id
        rescue => e
          entity = klass.new
          entity.errors.add :id, "There is no #{klass.to_s.downcase} number #{params[:id]}"
        end
      elsif !(entity = RecipeReference.lookup_recipe url) # Try again to find based on the extracted url
      # TODO elsif !(entity = RecipePageRef.recipe url) # Try again to find based on the extracted url
        # No id: create based on url
        params.delete :rcpref
        # Assigning title and picurl must wait until the url (and hence the reference) is set
        entity = klass.new
        if uri.to_s.match %r{^#{rp_url}} # Check we're not trying to link to a RecipePower page
          entity.errors.add :base, 'Sorry, can\'t cookmark pages from RecipePower. (Does that even make sense?)'
        elsif entity.is_a? Linkable
          entity.url = url
          # If this url is to the home of a site, return a Site object instead
          # Ignore leading and trailing slashes in comparing paths
          if uri.path.sub(/^\//, '').sub(/\/$/,'') == URI(entity.site.home).path.sub(/^\//, '').sub(/\/$/,'')
            entity.site.decorate.findings = findings
            return entity.site
          else
            entity.decorate.findings = findings # Now set the title, description, etc.
          end
        end
      end
    end
    entity
  end


end
