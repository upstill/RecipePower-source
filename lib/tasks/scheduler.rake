desc "This feed updater is called by the Heroku scheduler add-on"
task :update_feed => :environment do
    puts "Updating feeds..."
    Feed.update_now
    puts "done."
end
