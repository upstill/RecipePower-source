desc "This feed updater is called by the Heroku scheduler add-on"
task :update_feed => :environment do
    puts "Updating #{Feed.where(:approved => true).count.to_s} feeds in #{Rails.env}..."
    Feed.update_now
    puts "done."
end
