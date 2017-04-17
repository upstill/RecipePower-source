namespace :feeds do
  desc "TODO"

  # QA on recipes: try to get valid PageRef
  task update: :environment do
    Feed.where(approved: nil).order('last_post_date DESC').first(2).each { |feed|
      puts "******* Updating Feed ##{feed.id} '#{feed.title}' ****************"
      feed.bkg_go true
    }
  end

end
