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
    msgs = []
    PageRef.find_each { |pr|
      if pr.url != PageRef.standardized_url(pr.url) # i.e., it's not standardized
        msg = "PageRef ##{pr.id} on url #{pr.url} actually should be #{PageRef.standardized_url(pr.url)}...\n"
        extant = pr.class.find_by_url pr.url  # There may be another page_ref answering to this url
        if extant.id == pr.id
          msg << "...but new url is fine"
          pr.url = pr.url # ...which puts the url in standard format AND creates an alias on it
          pr.save
        else
          msg << "...but new url conflicts with PageRef ##{extant.id}"
          # PageRefServices.new(extant).absorb pr
        end
        msgs << msg
      end
    }
    # Now confirm that every PageRef has an alias based on its URL
    PageRef.includes(:aliases).find_each { |pr|
      unless pr.alias_for?(pr.url)
        msgs << "PageRef ##{pr.id} has url #{pr.url} without an alias"
        msgs << "...indexing_url is #{Alias.indexing_url pr.url}"
        msgs << "...aliases are #{pr.aliases.map &:url}"
      end
    }
    puts msgs
  end

end
