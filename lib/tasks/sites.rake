namespace :sites do
  desc "TODO"
  task :purge => :environment do
    s = Site.first
    p = PageRef.first
    domains = SitePageRef.pluck(:domain).uniq
    domains.each { |domain|
      sprs = SitePageRef.includes(:sites).where(domain: domain)
      nsites = 0
      roots = sprs.collect { |spr|
        pairs = spr.sites.pluck :id, :root
        nsites += pairs.count
        "    PageRef ##{spr.id}: "+pairs.collect { |pair| "#{pair.last} (#{pair.first})"}.join(', ')
      }
      if nsites > 1 # Indicating a potentially redundant domain
        puts "#{domain}:"
        puts roots
        puts
      end
    }
  end

  task :elide_slash => :environment do
    PageRef.where(type: 'SitePageRef').each { |spr|
      begin
        uri = URI spr.url
        uri.path = '' if uri.path == '/'
        url = uri.to_s
      rescue
        puts "Bad URL on ##{spr.id}: '#{spr.url}'"
        next
      end
      unless spr.url == url
        puts "Fixing ##{spr.id}: '#{spr.url}'"
        spr.aliases -= [url]
        spr.aliases |= [spr.url]
        spr.url = url
      end
    }
  end

  # Confirm that a site can be looked up via its PageRef's url
  task :lookup_url => :environment do
    PageRef.where(type: 'SitePageRef').each { |spr|
      found = SitePageRef.find_by_url(spr.url)
      if !found
        "#{spr.url} (#{spr.id}) not findable"
      elsif found.id != spr.id
        "'#{spr.url}' (#{spr.id}) finds '#{spr.url}' (#{spr.id})"
      end
    }
  end

  task :reports => :environment do
    # Every site needs to have a name (referent) and home (page_ref)
    puts Site.includes(:referent).to_a.collect { |site|
      next if site.referent
      "Site ##{site.id} ('#{site.home}' has no referent (ERROR) #{('but title is '+site.page_ref.title.to_s) if site.page_ref}" +
          "\n\t...with #{site.definition_page_refs.count} DefinitionPageRef(s) and #{site.recipe_page_refs.count} RecipePageRef(s)"
    }.compact.sort
    puts Site.includes(:page_ref).to_a.collect { |site| "Site ##{site.id} ('#{site.home}' has no page_ref (ERROR)" unless site.page_ref }.compact.sort

    # Every PageRef should have at least tried to go out
    badrefids = SitePageRef.bad.where.not(http_status: 200).pluck(:id)
    puts [
        (SitePageRef.where(url: nil).count.to_s + ' nil site urls'),
        ((SitePageRef.virgin.count+SitePageRef.processing.count).to_s + ' Site Page Refs need processing'),
        (SitePageRef.where(http_status: nil).count.to_s + ' Site Page Refs have no HTTP status'),
        (badrefids.count.to_s + " bad SitePageRefs: \n\t" + SitePageRef.where(id: badrefids).collect { |spr|
          "#{spr.id}: '#{spr.url}' (for site ##{spr.site_id}) -> #{spr.http_status}"
        }.join("\n\t"))
    ]
  end
end
