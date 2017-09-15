class PageRefServices
  attr_accessor :page_ref

  def initialize page_ref
    @page_ref = page_ref
    # @current_user = current_user
  end

  # Provide an array of label/type pairs for selecting the type of a pageref
  def self.type_selections
    [
        ['Recipe', 'RecipePageRef'],
        ['Site', 'SitePageRef'],
        # ['Referrable', 'ReferrablePageRef'],
        ['Definition', 'DefinitionPageRef'],
        ['Article', 'ArticlePageRef'],
        ['News Item', 'NewsitemPageRef'],
        ['Tip', 'TipPageRef'],
        ['Video', 'VideoPageRef'],
        ['Home Page', 'HomepagePageRef'],
        ['Product', 'ProductPageRef'],
        ['Offering', 'OfferingPageRef'],
        ['Event', 'EventPageRef']
    ]
  end

  # Try to translate a PageRef type into English
  def self.type_to_name type
    self.type_selections.find { |ts|
      ts.first if type == ts.last
    }
  end

  # Get a collectible entity for the PageRef, which may be the PageRef itself
  # If the pageref has an entity_id, lookup with that
  def entity params
    klass =
    case page_ref.type
      when 'RecipePageRef'
        Recipe
      when 'SitePageRef'
        Site
      else
        return page_ref.becomes(PageRef)
    end
    klass.find_by(id: params[:entity_id]) || begin
      # Initialize the entity from parameters and extractions, as needed
      # defaults = page_ref.decorate.translate_params params[:page_ref], entity
      defaults = {
          'Title' => params[:page_ref][:title],
          'href' => page_ref.url,
          'Image' => params[:page_ref][:picurl]
      }
      defaults.merge! params[:extractions] if params[:extractions]
      # Produce a set of initializers for the target class
      CollectibleServices.find_or_create(page_ref, defaults, klass)
    end
  end

  # Use the attributes of another (presumably b/c a new, identical page_ref is being created)
  def adopt other, force=false
    @page_ref.bkg_sync true # Wait until the gleanings come in
    if other && (other.id != @page_ref.id)
      @page_ref.title = other.title if force || @page_ref.title.blank?
    end
  end

  # Eliminate redundancy in the PageRefs by folding two into one
  def absorb other, force=false
    return if page_ref == other

    # Take on all the recipes of the other
    other.recipes.each { |other_recipe|
      other_recipe.page_ref = page_ref
      other_recipe.save
    } if other.respond_to? :recipes

    other.sites.each { |other_site|
      other_site.page_ref = page_ref
      other_site.save
    } if other.respond_to? :sites

    # Absorb referments, taking care to elide redundancy

    other.referent_ids.each { |ref_id|
      page_ref.referent_ids << ref_id unless page_ref.referent_ids.include?(ref_id)
    } if other.respond_to? :referent_ids

    # An important question is: which url (and associated status attributes) gets used in the product?
    # The default is to keep the absorber's attributes unless the other is shown to be good. The 'force'
    # parameter allows this issue to be forced.
    aliases = (page_ref.aliases + other.aliases + [other.url, page_ref.url]).uniq
    if force || ((page_ref.http_status != 200) && (other.http_status == 200))
      hard_attribs = other.attributes.slice *%w{ errcode http_status error_message url }
      puts "...taking #{hard_attribs} from other"
      page_ref.assign_attributes hard_attribs

      # Soft attributes are copied only if not already set
      soft_attribs = page_ref.class.mercury_attributes + %w{ link_text }
      soft_attribs.each { |attrname|
        unless page_ref.read_attribute(attrname).present?
          puts "...absorbing #{attrname} = #{other.read_attribute(attrname)}"
          page_ref.write_attribute attrname, other.read_attribute(attrname)
        end
      }
    end
    page_ref.aliases = aliases - [page_ref.url]

    other.destroy if other.id # May not have been saved
    page_ref.save
  end

  # Convert a PageRef (and its associated entity, if any) to a new type
  def convert entity_params={}, options={}
    type = entity_params[:page_ref_type]
    entity = options[:entity]
    convertible = case page_ref
                    when RecipePageRef
                      options[:convert_recipe]
                    when SitePageRef
                      false
                    else
                      true
                  end
    typeclass = type.constantize
    if newpr = typeclass.find_by_url(page_ref.url, false)
      # TODO What attributes do we impose on an existing page_ref?
      page_ref.destroy if convertible
    elsif convertible
      (newpr = page_ref.becomes typeclass).type = type
    else
      (newpr = page_ref.dup.becomes typeclass).type = type
    end
    # Now that we have a PageRef, build and initialize a corresponding Recipe or Site as necessary
    PageRefServices.new(newpr).entity page_ref: entity_params.except(:id, :page_ref_id)
  end

  def self.assert type, uri
    (type.present? ? type.constantize : PageRef).fetch uri
  end

  # Assert a reference to the given URL, linking back to a referent
  def self.assert_for_referent(uri, tag_or_referent, type=:Definition )
    pr = "#{type}PageRef".constantize.fetch uri
    self.new(pr).assert_referent tag_or_referent if pr.errors.empty?
    pr
  end

  # Associate this page_ref with the given referent.
  # NB: had better be a ReferrableReferent or subclass thereof
  def assert_referent tag_or_referent
    rft =
        case tag_or_referent
          when Tag
            Referent.express tag_or_referent
          else
            tag_or_referent
        end
    if rft && !page_ref.referent_ids.include?(rft.id)
      page_ref.referents << rft
      page_ref.save
    end
  end

  def make_match type, url
    return page_ref if page_ref.answers_to?(type, url)
    typeclass = (type.present? ? type.constantize : PageRef)
    if page_ref.type == type
      # The given page_ref is of the appropriate type.
      # If there is no other page_ref of that type with this url, we can just add the url
      if other = typeclass.find_by_url(type, url)
        other
      else
        # We can adopt this url for ourselves
        page_ref.aliases << url
        page_ref
      end
    else
      typeclass.fetch url
    end
  end

  # Convert any relative paths in PageRef urls by resort to aliases
  def self.join_urls what
    (what.to_s+'PageRef').constantize.where(domain: nil).collect { |pr|
      report = "Joining URLS for #{pr.class} ##{pr.id} '#{pr.url}'"
      if pr.url.present?
        uri = (URI(pr.url) rescue nil)
        # report << PageRefServices.new(pr).join_url
        if !(uri && uri.scheme.present? && uri.host.present?)
          report << "Rationalizing bad url '#{pr.url}' (PageRef ##{pr.id}) using '#{pr.aliases.first}'"
          pr.url = URI.join(pr.aliases.shift, uri || pr.url)
          report << "\n\t...to #{pr.url}"
          pr.bkg_go true
        elsif pr.domain.blank?
          pr.domain = uri.host
          pr.save
        end
      elsif what == 'Definition'
        if rfm = Referment.find_by(referee_type: 'PageRef', referee_id: pr.id)
          report << "\n...Couldn't destroy b/c attached to Referment #{rfm.id}"
        else
          pr.destroy
          report << "\n...destroyed URL for #{pr.class} ##{pr.id} '#{pr.url}'"
        end
      else
        report << "\n...Couldn't destroy b/c not a Definition"
      end
    }
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
      elsif page_ref.aliases.present?
        page_ref.url = page_ref.aliases.pop
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
      page_ref.becomes(PageRef).bkg_enqueue priority: 10 # Must be enqueued as a PageRef b/c subclasses aren't recognized by DJ
      puts "Enqueued #{page_ref.class.to_s} ##{page_ref.id} '#{page_ref.url}' to get status"
      page_ref.bkg_asynch
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

  # Make sure the page_ref has a site
  def ensure_site
    page_ref.site ||= Site.find_or_create_for(page_ref.url) unless (page_ref.class == SitePageRef)
    page_ref.save
  end

  # Try to make a URL good by applying a pattern (string or regexp)
  def try_substitute old_ptn, subst
    ([page_ref.url] + page_ref.aliases).each { |old_url|
      if old_url.match(old_ptn)
        new_url = old_url.sub old_ptn, subst
        puts "Trying to substitute #{new_url} for #{old_url} on PageRef ##{page_ref.id}"
        klass = page_ref.class
        new_page_ref = klass.fetch new_url
        puts "...got PageRef ##{new_page_ref.id || '<nil>'} '#{new_page_ref.url}' http_status #{new_page_ref.http_status}"
        unless new_page_ref.errors.any?
          if new_page_ref.id # Existed prior =>
            # Make the old page_ref represent the new URL
            PageRefServices.new(new_page_ref).absorb page_ref
            return new_page_ref
          elsif extant = klass.find_by_url(new_page_ref.url) # new_page_ref.url already exists
            puts "...returning ##{page_ref.id || '<nil>'} '#{page_ref.url}' http_status #{page_ref.http_status}"
            epr = PageRefServices.new extant
            epr.absorb page_ref
            epr.absorb new_page_ref
            return extant
          else
            absorb new_page_ref, true
            puts "...returning ##{page_ref.id || '<nil>'} '#{page_ref.url}' http_status #{page_ref.http_status}"
            return page_ref
          end
        end
      end
    }
    nil
  end
end
