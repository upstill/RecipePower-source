class PageRefServices
  attr_accessor :page_ref

  def initialize page_ref
    @page_ref = page_ref
    # @current_user = current_user
  end

  # The PageRef kinds that are available for a user to declare.
  # normally, :link, :referrable, :offering, and :event are excluded, but they can be forced
  # by using them as parameters
  def self.selectable_kinds include=nil
    PageRef.kinds.except *([:link, :referrable, :offering, :event] - (include || []).map(&:to_a))
  end

  # Provide an array of label/type pairs for selecting the type of a pageref
  def self.kind_selections options={}
    kinds = PageRefServices.selectable_kinds options[:include]
    except = (options[:except] || []).map &:to_s
    kinds.except(*except).collect { |kind, kind_id| [ PageRef.kind_name(kind), kind ]}
  end

  # Try to translate a PageRef kind into English
  def self.kind_to_name kind
    kind.is_a?(Integer) ? self.kind_selections.find { |ts| kind == ts.last }.first : kind.gsub('_', ' ').capitalize
  end

  # Ensure the existence of a page_ref of a particular kind with the given url
  def self.assert kind, url
    if pr = PageRef.fetch(url)
      pr.kind = kind
    end
    pr.persisted? || pr.valid?
    pr
  end
  
  # Get a collectible, taggable entity for the PageRef. Five possibilities:
  # 1) If it has an accompanying site, return the site
  # 2) If it has an accompanying recipe, return that
  # 3) If its URL is the domain root (has no path), create and return a new site
  # 4) If its kind is :recipe, create and return a new recipe
  # 5) Otherwise, just return the PageRef itself
  def editable_entity called_for=nil, params={}
    if called_for.is_a? Hash
      called_for, params = nil, called_for
    end
    (page_ref unless page_ref.recipe? || page_ref.site?) ||
        (called_for if called_for.is_a?(Recipe) || called_for.is_a?(Site)) ||
        (page_ref.id && (Site.find_by(page_ref_id: page_ref.id) || Recipe.find_by(page_ref_id: page_ref.id))) ||
    begin
      # Special case: a request for a recipe on a domain (no path) gets diverted to create a site by default
      klass = page_ref.site? || URI(page_ref.url).path.length < 2 ? Site : Recipe
      # Initialize the recipe from parameters and extractions, as needed
      # defaults = page_ref.decorate.translate_params params[:page_ref], entity
      defaults = {
          'Title' => params[:page_ref][:title],
          'href' => page_ref.url,
          'Image' => params[:page_ref][:picurl]
      }
      params[:extractions]&.each do |key, value| # Transfer the extractions to the defaults
        defaults[key] = value
      end
      # Produce a set of initializers for the target class
      CollectibleServices.find_or_build page_ref, defaults, klass
    end
  end

  # Use the attributes of another (presumably b/c a new, identical page_ref is being created)
  def adopt other, force=false
    @page_ref.bkg_land # Wait until the gleanings come in
    if other && (other.id != @page_ref.id)
      @page_ref.title = other.title if force || @page_ref.title.blank?
    end
  end

  # Eliminate redundancy in the PageRefs by folding two into one
  def absorb other, options={}
    return if page_ref == other

    # Take on all the recipes of the other
    other.recipes.each { |other_recipe|
      other_recipe.page_ref = page_ref
      other_recipe.save
    }

    other.sites.each { |other_site|
      other_site.page_ref = page_ref
      other_site.save
    }

    # Absorb referments, taking care to elide redundancy

    other.referent_ids.each { |ref_id|
      page_ref.referent_ids << ref_id unless page_ref.referent_ids.include?(ref_id)
    } if other.respond_to? :referent_ids

    # An important question is: which url (and associated status attributes) gets used in the product?
    # The default is to keep the absorber's attributes unless the other is shown to be good. The 'force'
    # parameter allows this issue to be forced.
    # aliases = (page_ref.aliases + other.aliases + [other.url, page_ref.url]).uniq
    if options[:force] || ((page_ref.http_status != 200) && (other.http_status == 200))
      hard_attribs = other.attributes.slice *%w{ errcode http_status error_message url }
      puts "...taking #{hard_attribs} from other"
      page_ref.assign_attributes hard_attribs

      # Soft attributes are copied only if not already set
      soft_attribs = other.ready_attributes + %w{ link_text }
      soft_attribs.each { |attrname|
        unless page_ref.read_attribute(attrname).present?
          puts "...absorbing #{attrname} = #{other.read_attribute(attrname)}"
          page_ref.send "#{attrname}=", other.send(attrname)
        end
      }
    end
    # page_ref.aliases = aliases - [page_ref.url]
    other.aliases.each { |al| page_ref.aliases << al unless page_ref.aliases.exists? url: al.url }

    if other.id # May not have been saved
      if options[:retain]
        other.save
      else
        other.destroy
      end
    end
    page_ref.save
  end

  # So a PageRef exists; ensure that it has valid status and http_status
  def ensure_status force=false
    # Ensure that each PageRef has status and http_status
    # First, check on the url (may lack host and/or scheme due to earlier bug)
    sentences = []
    while (uri = safe_parse(sanitize_url page_ref.url)) && (uri.host.blank? || uri.scheme.blank?)
      if uri.scheme.blank?
        uri.scheme = 'http'
        page_ref.http_status = nil unless page_ref.title.present?
        page_ref.url = uri.to_s
      else
        break
      end
    end
    if page_ref.url_changed? && (extant = page_ref.class.find_by_url page_ref.url) && (extant.id != page_ref.id)
      # Replacement URL is already being serviced by another PageRef
      PageRefServices.new(extant).absorb page_ref
      return "Destroyed redundant #{page_ref.class} ##{page_ref.id}"
    end
    if page_ref.title.present? # We assume that Mercury has done its job
      return "Status already 200 on 'good' PageRef##{page_ref.id} '#{page_ref.url}'" if page_ref.http_status == 200 && page_ref.good?
      page_ref.http_status = 200
      page_ref.good!
      sentences << "Set status on PageRef##{page_ref.id} '#{page_ref.url}': http_status '#{page_ref.http_status}', status '#{page_ref.status}', error '#{page_ref.error_message}"
    end
    # Many circumstances under which we go out to check the reference, not nec. for the first time
    if (page_ref.http_status != 200) || !(page_ref.bad? || page_ref.good?) || page_ref.url_changed? || force
      page_ref.bkg_launch priority: 10 # Must be enqueued as a PageRef b/c subclasses aren't recognized by DJ
      puts "Enqueued #{page_ref.class.to_s} ##{page_ref.id} '#{page_ref.url}' to get status"
      page_ref.bkg_land
      puts "...returned"
      sentences << "Ran #{page_ref.class.to_s} ##{page_ref.id} '#{page_ref.url}' err_msg #{page_ref.error_message} to get status: now #{page_ref.http_status}"
    else
      sentences << "#{page_ref.class.to_s} ##{page_ref.id} '#{page_ref.url}' is okay: status '#{page_ref.status}' http_status = #{page_ref.http_status}, url #{page_ref.url_changed? ? '' : 'not '} changed."
    end
    if (page_ref.http_status == 666) &&
        (match = page_ref.error_message.match(/tried to assert existing url '(.*)'$/)) &&
        match[1] &&
        (extant = page_ref.class.find_by_url match[1]) &&
        (extant.id != page_ref.id)
      sentences << "Found match PageRef ##{extant.id}"
      absorb extant
      page_ref.good!
    end
    sentences.join "\n\t"
  end
end
