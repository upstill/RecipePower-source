namespace :feeds do
  desc "TODO"

  # QA on recipes: try to get valid PageRef
  task update: :environment do
    Feed.where(approved: nil).order('last_post_date DESC').first(2).each { |feed|
      puts "******* Updating Feed ##{feed.id} '#{feed.title}' ****************"
      feed.bkg_land true
    }
  end

  # Make sure all visible feeds are queued for updates, and conversely
  task scrape: :environment do
    Feed.where.not(approved: true, dj_id: nil).each { |feed|
      puts "Killing updates for Feed ##{feed.id}: '#{feed.title}'"
      feed.bkg_kill
    }
    Feed.where(approved: true, dj_id: nil).each { |feed|
      puts "Launching updates for Feed ##{feed.id}: '#{feed.title}'"
      feed.launch_update true
    }
  end

  # Ensure that the entry count is correct for each feed
  task count: :environment do
    Feed.all.pluck(:id).each { |id|
      puts "Resetting counters for Feed #{id}"
      Feed.reset_counters(id, :feed_entries)
    }
  end

end
