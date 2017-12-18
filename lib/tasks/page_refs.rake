namespace :page_refs do
  desc "TODO"

  # Nuke answers.com page_refs (because they're useless)
  task fix_answers: :environment do
    s = Site.first
    pr = PageRef.first
    dpr = DefinitionPageRef.find_by url: "http://www.answers.com"
    dpr.referments.delete_all
    dpr.aliases = []
    dpr.save
  end

  # Ensure that each page_ref can be found by its indexing_url
  task fix_urls: :environment do
    count = 0
    failures = []
    PageRef.all.each { |pr|
      if pr.url != indexing_url(pr.url)
        extant = pr.class.find_by_url(pr.url)
        if !extant
          pr.aliases += [indexing_url(pr.url)]
          pr.save
          count += 1
        elsif extant.id != pr.id
          failures << [pr.id, extant.id]
        end
      end
    }
    puts "#{count} PageRefs fixed; #{failures.count} Failures"
    destroyed = []
    failures.each { |pair|
      PageRef.where(id: pair).to_a.each { |pr|
        if pr.site
          puts "#{pr.class.to_s} ##{pr.id} has site ##{pr.site.id}"
          next
        end
        case pr
          when SitePageRef
            if pr.sites.count > 0
              puts "SitePageRef ##{pr.id} has sites"
              next
            end
          when RecipePageRef
            if pr.recipes.count > 0
              puts "RecipePageRef ##{pr.id} has recipes"
              next
            end
          when ReferrablePageRef
            if pr.referents.count > 0
              puts "#{pr.class.to_s} ##{pr.id} has referents"
              next
            end
          else
            puts "#{pr.class.to_s} ##{pr.id} is non-ordinary type"
            next
        end
        destroyed << "#{pr.class.to_s} ##{pr.id}"
        pr.destroy
      }
    }
    puts "Destroyed #{destroyed.count} PageRefs:"
    puts destroyed
  end

  task fix_references: :environment do
    # run task sites:convert_references
    # run task recipes:convert_references
    # run task definitions:convert_references
    def self.fix_references what=nil
      # Make sure bad and good status align with existence of 'domain' attribute
      what = what.nil? ? :all : what.to_sym
      reports = []
      # Sites should be setup first so that other page_refs get them
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

      # Invoke recipes: reports (reports += self.recipe_reports) if [:all, :recipes].include? what
      # Invoke definitions: reports (reports += self.def_reports) if [:all, :definitions].include? what
      # Invoke sites: reports (reports += self.site_reports) if [:all, :sites].include? what
      puts reports.compact
    end

  end

end
