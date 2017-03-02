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

  task :convert_references => :environment do
    reports = [ '***** rake sites:convert_references ********']
    (s = Site.find_by(id: 3463)) && s.destroy
    Site.includes(:references).where(page_ref_id: nil).each { |site|
      SiteServices.new(site).convert_references if site.references.present?
    } # Only convert the unconverted
    # Clean up the PageRefs with nil URLs
    PageRef::SitePageRef.where(url: nil).collect { |spr|
      site = Site.find_by(page_ref_id: spr.id)
      spr.destroy
      if site
        site.page_ref = nil
        site.save
        reports << SiteServices.new(site).convert_references
      end
    }

    # SiteServices.fix_sites
    # Ensure that each PageRef (except SitePageRefs) has a corresponding site
      # Define new sites as needed
      [
          { name: 'NYTimes Diners Journal', root: 'dinersjournal.blogs.nytimes.com', sample: 'http://www.nytimes.com/pages/dining/index.html'},
          { name: 'PBS Food', root: 'www.pbs.org/food', home: 'http://www.pbs.org/food'},
          { name: 'UK TV Good Food', root: 'goodfood.uktv.co.uk', home: 'http://goodfood.uktv.co.uk/'},
          { root: 'goodfood.uktv.co.uk', home: 'http://goodfood.uktv.co.uk' },
          { root: 'ricette.giallozafferano.it', home: 'http://ricette.giallozafferano.it' },
          { root: 'www.dailymail.co.uk', home: 'http://www.dailymail.co.uk' },
          { root: 'www.eatingwell.com', home: 'http://www.eatingwell.com' },
          { root: 'www.theguardian.com', home: 'https://www.theguardian.com' },
          { root: 'ww2.kqed.org/bayareabites', home: 'https://ww2.kqed.org/bayareabites' },
          { root: 'www.yummly.co', home: 'http://www.yummly.com/' },
          { root: 'www.shutterbean.com', home: 'http://www.shutterbean.com' },
          { root: 'www.annies-eats.com', home: 'http://www.annies-eats.com' },
          { root: 'www.bite.co.nz', home: 'http://www.bite.co.nz' },
          { root: 'www.brm-icecream.com', home: 'http://www.brm-icecream.com' },
          { root: 'www.cdkitchen.com', home: 'http://www.cdkitchen.com' },
          { root: 'www.gourmetsleuth.com', home: 'http://www.gourmetsleuth.com' },
          { root: 'www.hogarmania.com', home: 'http://www.hogarmania.com' },
          { root: 'www.lespetitsmacarons.com', home: 'http://www.lespetitsmacarons.com' },
          { root: 'www.tastebook.com', home: 'http://www.tastebook.com' },
          { root: 'www.thepauperedchef.com', home: 'http://www.thepauperedchef.com' },
          { root: 'www.washingtonpost.com', home: 'http://www.washingtonpost.com' },
          { root: 'bestbyfarr.wordpress.com', home: 'https://bestbyfarr.wordpress.com' },
          { root: 'en.wikipedia.org', home: 'https://en.wikipedia.org' },
          { root: 'patijinich.com', home: 'https://patijinich.com' },
          { root: 'www.evernote.com', home: 'https://www.evernote.com' },
          { root: 'saltandwind.com', home: 'http://saltandwind.com' },
          { root: 'www.washingtonpost.com/lifestyle/food', home: 'https://www.washingtonpost.com/lifestyle/food' },
          { name: 'playing with fire and water', root: 'www.playingwithfireandwater.com', home: 'http://www.playingwithfireandwater.com' },
          { name: 'Mexico Cooks', root: 'mexicocooks.typepad.com/mexico_cooks', home: 'http://mexicocooks.typepad.com/mexico_cooks/'},
          { name: 'The Guardian UK Food&Drink', root: 'www.theguardian.com/lifeandstyle', sample: 'https://www.theguardian.com/lifeandstyle/food-and-drink'}
      ].each { |initializer|
        unless Site.where(root: initializer[:root]).exists?
          s = Site.create(initializer)
          if s.page_ref && s.page_ref.title.present?
            s.name = s.page_ref.title
            s.save
          end
        end
      }
      [ PageRef::RecipePageRef, PageRef::DefinitionPageRef ].each { |refclass|
        refclass.where(site_id: nil).collect { |pageref|
          puts "Fixing site for #{pageref.type} ##{pageref.id}: #{pageref.url}"
          if pageref.site = Site.find_for(pageref.url)
            pageref.save
            pageref
          end
        }.compact
      }

    # SiteServices.fix_roots
    # Site.find_by(sample: '/').destroy
    if site = Site.find_by(id: 3332)
      site.home.sub! '[node-path]', ''
      site.save
    end
    Site.includes(:page_ref).where(root: nil).collect { |site|
      ss = SiteServices.new(site)
      ss.fix_root if site.page_ref
    }.compact # Only convert the unconverted

    # SiteServices.fix_page_refs
    # Ensure that every site with a viable home link has a page_ref
    Site.where(page_ref_id: nil).collect { |site|
      # Ensure that every site with a viable home link has a page_ref
      puts "Fixing PageRef for Site ##{site.id} ('#{site.home}')"
      if site.home.present?
        site.page_ref = PageRef::SitePageRef.fetch site.home
        site.save
        if site.errors.any?
          puts "...fails to get PageRef: #{site.errors.messages}"
        else
          puts "...gets PageRef ##{site.page_ref_id}"
        end
        puts fix_root if site.root.blank?
      else
        puts "...couldn't create PageRef for empty home (!!)"
      end
    }

    PageRef::SitePageRef.all.each { |pr| PageRefServices.new(pr).ensure_status }
    reports += PageRefServices.join_urls(Site).flatten.compact
    reports += SitePageRef.all.collect { |pr| PageRefServices.new(pr).ensure_status }.flatten.compact.sort
    puts reports
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
