# require 'page_ref.rb'
class PageRefServices
  attr_accessor :page_ref

  def initialize page_ref
    @page_ref = page_ref
    # @current_user = current_user
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

    other.referments.each { |rfm|
      rfm.referee = page_ref
      rfm.save
    } if other.respond_to? :referments

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

  # Convert a reference, either creating a new PageRef or merging it with another
  def self.convert_reference reference, extant_pr=nil

    # Is the only difference between the two URLs a trailing slash in the link?
    def self.functionally_equivalent pr1, pr2
      uri1 = URI.parse pr1.url
      uri2 = URI.parse pr2.url
      return true if uri1 && uri1 && (uri2.path.sub /\/$/, '') == (uri1.path.sub /\/$/, '')
      # Mercury does not give the redirected URL for a "temporary" redirect, so we compare content
      c1 = pr1.content || ''
      return true if (c1.length > 1) && (c1 == (pr2.content || ''))
    end

    klass = reference.class.to_s.sub(/Reference$/, 'PageRef').constantize
    pr = klass.fetch reference.url
    return pr if pr.errors.any?
    case extant_pr
      when nil # No PageRef existed prior
        pr.save if !pr.id
        pr
      when pr
        extant_pr
      else # There's an existing page_ref and it doesn't match the new one
        # if functionally_equivalent(extant_pr, pr) # If it's only a difference of the trailing slash...
        # ...just merge the new pr into the old
        PageRefServices.new(extant_pr).absorb pr
        extant_pr
      # else
      # raise %Q{Reference #{reference.id} (#{reference.url}) fails to merge its PageRef (url=#{pr.url}) with existing PageRef #{extant_pr.id} (#{[[extant_pr.url]+extant_pr.aliases].join(', ')})}
      # end
    end
  end

  def self.fix_references what=nil
    # Make sure bad and good status align with existence of 'domain' attribute
    what = what.nil? ? :all : what.to_sym
    reports = []
    # Sites should be setup first so that other page_refs get them
    if [:all, :sites].include? what
      reports += SiteServices.convert_references
      reports += self.join_urls(Site).flatten.compact
      reports += SitePageRef.all.collect { |pr| PageRefServices.new(pr).ensure_status }.flatten.compact.sort
    end
    if [:all, :recipes].include? what
      reports += RecipeServices.convert_references
      reports += self.join_urls Recipe
      # Finally, ensure that all RecipePageRef objects have either :good or :bad status and also valid http_status
      reports += RecipePageRef.all.collect { |pr| PageRefServices.new(pr).ensure_status }.flatten.compact.sort
      RecipePageRef.where(site_id: nil).collect { |pr| PageRefServices.new(pr).ensure_site }.flatten.compact.sort
    end
    if [:all, :definitions].include? what
      reports += RefermentServices.convert_references
      reports += self.join_urls 'Definition'
      reports += DefinitionPageRef.all.collect { |pr| PageRefServices.new(pr).ensure_status }.flatten.compact.sort
      reports += DefinitionPageRef.where(site_id: nil).collect { |pr| PageRefServices.new(pr).ensure_site }.flatten.compact.sort
    end

    # QA
    bad_urls = PageRef.where.not('url LIKE ?', 'http%')
    reports << "#{bad_urls.count} PageRefs with funky URLS"
    reports += bad_urls.collect { |rpr| "\t#{rpr.url} (#{rpr.class} ##{rpr.id})" }.sort

    (reports += self.recipe_reports) if [:all, :recipes].include? what
    (reports += self.def_reports) if [:all, :definitions].include? what
    (reports += self.site_reports) if [:all, :sites].include? what
    puts reports.compact
    nil
  end

  # Convert any relative paths in PageRef urls by resort to aliases
  def self.join_urls what
    (what.to_s+'PageRef').constantize.where(domain: nil).collect { |pr|
      report = "Joining URLS for #{pr.class} ##{pr.id} '#{pr.url}'"
      if pr.url.present?
        report << PageRefServices.new(pr).join_url
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

  def join_url
    uri = (URI(page_ref.url) rescue nil)
    report = nil
    if !(uri && uri.scheme.present? && uri.host.present?)
      report = "Rationalizing bad url '#{page_ref.url}' (PageRef ##{page_ref.id}) using '#{page_ref.aliases.first}'"
      page_ref.url = URI.join(page_ref.aliases.shift, uri || page_ref.url)
      report << "\n\t...to #{page_ref.url}"
      page_ref.bkg_perform
    elsif page_ref.domain.blank?
      page_ref.domain = uri.host
      page_ref.save
      report = ''
    end
    report
  end

  def self.recipe_reports
    reports = []
    # Every recipe needs to have a site and a url (page_ref)
    # reports << Recipe.includes(:referent).to_a.collect { |recipe| "Recipe ##{recipe.id} has no referent (ERROR)" unless recipe.referent }.compact

    reports << RecipePageRef.where(url: nil).count.to_s + ' nil urls in RecipePageRefs'
    reports << RecipePageRef.where(site_id: nil).count.to_s + ' nil sites in RecipePageRefs'
    reports << Recipe.includes(:page_ref).collect { |rcp| true if rcp.page_ref.url.blank? }.compact.count.to_s + " nil URLs in recipes"

    bad = RecipePageRef.includes(:recipes).where.not(status: [0,1,2], http_status: 200)
    unreachables = Recipe.includes(:page_ref, :gleaning).all.collect { |recipe| recipe if recipe.reachable? == false }.compact
    headless = Recipe.includes(:page_ref).where(page_ref_id: nil)
    # Every PageRef should have at least tried to go out
    reports += [
        ((RecipePageRef.virgin.includes(:recipes).count+RecipePageRef.processing.count).to_s + ' Recipe Page Refs need processing'),
        (RecipePageRef.includes(:recipes).where(http_status: nil).count.to_s + ' Recipe Page Refs have no HTTP status'),
        (bad.count.to_s + " bad recipe refs\n\t" + bad.collect { |rpr| "'#{rpr.url}' (#{rpr.id}) (http_status = #{rpr.http_status}) used by recipe(s) #{rpr.recipe_ids} "}.sort.join("\n\t")),
        (unreachables.count.to_s + " recipe(s) with unreachable URL (bad PageRef and bad gleaning)\n\t" + unreachables.collect { |badrecipe| "#{badrecipe.page_ref.url if badrecipe.page_ref} (#{badrecipe.id}) "}.sort.join("\n\t"))
    ]
    reports << (["#{headless.count} recipes with no page ref:"] +
        headless.collect { |recipe| "Recipe ##{recipe.id} '#{recipe.url}'" }).join("\n\t")
    reports
  end

  def self.def_reports
    reports = []
    # Every PageRef needs to have a parsable URL
    reports << PageRef.where(type: 'DefinitionPageRef', url: nil).count.to_s + ' nil urls in DefinitionPageRefs'
    reports << Referent.where(type: 'DefinitionReferent').includes(:page_ref).to_a.collect { |defref| "Definition ##{defref.id} has no page_ref (ERROR)" unless defref.page_ref }.compact.sort

    reports << DefinitionPageRef.where(site_id: nil).count.to_s + ' nil sites in DefinitionPageRefs'
    # Every PageRef should have at least tried to go out
    bad_def_refs = PageRef.bad.where("type = 'DefinitionPageRef' and http_status != 200")
    reports += [
        ((PageRef.virgin.where(type: 'DefinitionPageRef').count+DefinitionPageRef.processing.count).to_s + ' Definition Page Refs need processing'),
        (PageRef.where(type: 'DefinitionPageRef', http_status: nil).count.to_s + ' Definition Page Refs have no HTTP status'),
        (bad_def_refs.count.to_s + " bad definition refs: \n\t" + bad_def_refs.collect { |dpr| "#{dpr.url} (#{dpr.id}) http_status = '#{dpr.http_status}'"}.sort.join("\n\t"))
    ]
    reports
  end

  def self.site_reports
    reports = []
    # Every site needs to have a name (referent) and home (page_ref)
    reports << Site.includes(:referent).to_a.collect { |site| "Site ##{site.id} ('#{site.home}' has no referent (ERROR)" unless site.referent }.compact.sort
    reports << Site.includes(:page_ref).to_a.collect { |site| "Site ##{site.id} ('#{site.home}' has no page_ref (ERROR)" unless site.page_ref }.compact.sort

    # Every PageRef should have at least tried to go out
    badrefids = SitePageRef.bad.where.not(http_status: 200).pluck(:id)
    reports += [
        (SitePageRef.where(url: nil).count.to_s + ' nil site urls'),
        ((SitePageRef.virgin.count+SitePageRef.processing.count).to_s + ' Site Page Refs need processing'),
        (SitePageRef.where(http_status: nil).count.to_s + ' Site Page Refs have no HTTP status'),
        (badrefids.count.to_s + " bad SitePageRefs: \n\t" + SitePageRef.where(id: badrefids).collect { |spr| "#{spr.id}: '#{spr.url}' -> #{spr.http_status}"}.join("\n\t"))
    ]
    reports
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
      page_ref.bkg_wait
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

  # Check for url collisions between pagerefs of a given type.
  # This applies to aliases as well as urls, i.e. any given url must map uniquely to one pageref, whether through
  # the url attribute or via aliases.
  # This method repairs the trivial case in which a pageref's url also appears in its aliases
  def self.report_urls type=:recipe
    klass = "#{type.to_s.capitalize}PageRef".constantize
    map = {}
    klass.all.pluck(:id, :url, :aliases).each { |arr|
      id, url, aliases = *arr
      if aliases.include? url
        pr = PageRef.find(id)
        pr.aliases.delete url
        pr.save
      end
      (aliases + [url]).each { |url| (map[url] ||= []) << id }
    }
    map.keep_if { |url, set| set.count > 1 }
  end
end
