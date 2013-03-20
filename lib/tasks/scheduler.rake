desc "This feed updater is called by the Heroku scheduler add-on"
task :update_feed => :environment do
    env = Rails.env.development? ? "Development" : (Rails.env.production? ? "Production" : "??")
    puts "Updating feeds in #{env}..."
    puts "Environment: "+Rails.env
    Feed.where(:approved => true).count.to_s+" feeds to update."
    Feed.update_now
    puts "done."
end
