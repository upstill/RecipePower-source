namespace :cache do
  desc "Clear Rails.cache"
  task clear: :environment do
    Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(Rails.configuration.cache_store)
    Rails.cache.clear
    puts "Successfully cleared Rails.cache!"
  end
end