class CollectibleServices

  attr_accessor :entity

  delegate :owner, :ordering, :name, :name_tag, :tags, :notes, :availability, :owner_id, :to => :entity

  def initialize entity
    self.entity = entity
  end

  # Either fetch an existing object or make a new one #    -- of the given klass, #    -- using the page_ref for its external reference #    -- parametrized by the params.
  # If the params have an :id, we find on that, otherwise we look
  # for a record matching the :url. If there are no params, just return a new recipe
  # If a new recipe record needs to be created, we also do QA on the provided URL
  # and dig around for a title, description, etc.
  # Either way, we also make sure that the recipe is associated with the given user
  def self.find_or_create params_or_page_ref, extractions = nil, klass=Recipe
    extractions, klass = nil, extractions if extractions.is_a?(Class)
    if params_or_page_ref.is_a?(PageRef)
      params, page_ref = { url: params_or_page_ref.url }, params_or_page_ref
    else
      params, page_ref = params_or_page_ref, nil
    end
    # Recipe (or whatever) exists and we're just touching it for the user
    return klass.find(params[:id]) if params[:id]
    if extractions.is_a? Class
      extractions, klass = nil, extractions
    end
    if entity = klass.find_by_url_and(params)  # Pre-existing => ignore extractions
      return entity
    end

    # Get findings from the extractions (parameters derived directly from the page)
    unless findings = FinderServices.from_extractions(params, extractions)
      entity = klass.new params
      entity.errors[:url] = 'Doesn\'t appear to be a working URL'
      return entity
    end

    # Construct a valid URL from the given url and the extracted URI or href
    url = valid_url(findings.result_for('URI'), params[:url]) ||
          valid_url(findings.result_for('href'), params[:url])
    # url = findings.result_for('URI') || findings.result_for('href') || url
    uri = URI url
    if uri.blank?
      entity = klass.new
    elsif (id = params[:id].to_i) && (id > 0) # id of 0 means create a new entity
      begin
        entity = klass.find id
      rescue => e
        entity = klass.new
        entity.errors.add :id, "There is no #{klass.to_s.downcase} number #{params[:id]}"
      end
    elsif !(entity = klass.find_by_url_and params.merge(url: url)) # Try again to find based on the extracted url
      # No id: create based on url
      params.delete :rcpref
      # Assigning title and picurl must wait until the url (and hence the page_ref) is set
      entity = (klass==Site) ? Site.find_or_build(page_ref.try(:url) || url) : klass.new
      if uri.to_s.match %r{^#{rp_url}} # Check we're not trying to link to a RecipePower page
        entity.errors.add :base, 'Sorry, can\'t cookmark pages from RecipePower. (Does that even make sense?)'
      else
        if page_ref
          entity.page_ref ||= page_ref # Assign the provided page_ref to the entity
        else
          entity.url = url unless entity.url.present? # No pre-existing page_ref => ensure that the entity has one
        end
        entity.decorate.findings = findings # Now set the title, description, etc.
      end
      entity.save # after_save callback is invoked for new record, queueing background processing
    end
    entity
  end

end
