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
          pr.aliases |= [indexing_url(pr.url)]
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

end
