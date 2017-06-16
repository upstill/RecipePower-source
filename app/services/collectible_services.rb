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
  def self.find_or_create params, extractions = nil, klass=Recipe
    # Recipe (or whatever) exists and we're just touching it for the user
    return klass.find(params[:id]) if params[:id]
    if extractions.is_a? Class
      extractions, klass = nil, extractions
    end
    url = params[:url]
    if (entity = klass.find_by_url url)  # Pre-existing => ignore extractions
      return entity
    end

    # Get findings from the extractions (parameters derived directly from the page)
    unless findings = FinderServices.from_extractions(params, extractions)
      entity = klass.new params
      entity.errors[:url] = 'Doesn\'t appear to be a working URL'
      return entity
    end

    # Construct a valid URL from the given url and the extracted URI or href
    url = valid_url(findings.result_for('URI'), url) || valid_url(findings.result_for('href'), url)
    # url = findings.result_for('URI') || findings.result_for('href') || url
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
    elsif !(entity = klass.find_by_url url) # Try again to find based on the extracted url
      # No id: create based on url
      params.delete :rcpref
      # Assigning title and picurl must wait until the url (and hence the page_ref) is set
      entity = klass.new
      if uri.to_s.match %r{^#{rp_url}} # Check we're not trying to link to a RecipePower page
        entity.errors.add :base, 'Sorry, can\'t cookmark pages from RecipePower. (Does that even make sense?)'
      elsif entity.is_a? Pagerefable
        entity.url = url # Defines a page_ref on the url
        # If this url is to the home of a site, return that Site object instead
        if site = entity.page_ref.site # ...which should have been created in the course of assigning the url
          site_uri = URI site.home
          # We assume that if the host and path of the two entities match, it's a site
          if (uri.host == site_uri.host) &&
              # Ignore leading and trailing slashes in comparing paths
              uri.path.sub(/^\//, '').sub(/\/$/, '') == site_uri.path.sub(/^\//, '').sub(/\/$/, '')
            site.decorate.findings = findings
            return site
          end
        end
        entity.decorate.findings = findings # Now set the title, description, etc.
      end
    end
    entity
  end


end
