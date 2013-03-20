desc "This feed updater is called by the Heroku scheduler add-on"
task :update_feed => :environment do
    puts "Updating feeds..."
    Feed.where(:approved => true).count.to_s+" feeds to update."
    Feed.update_now
    puts "done."
end
