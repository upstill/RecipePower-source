RP::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.action_controller.perform_caching = true
  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  # config.cache_store = :file_store, './tmp/cache'
  # config.cache_store = :null_store # No caching during development
  config.cache_store = :memory_store, { size: 128.megabytes }

  # See everything in the log (default is :info)
  config.log_level = :debug

  # Log error messages when you accidentally call methods on nil.
  # Obsolete in Rails 4: config.whiny_nils = true 

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true # false
  config.action_mailer.default_url_options = { :protocol => :https, :host => 'local.recipepower.com:3000' }
  
  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Expands the lines which load the assets
  config.assets.debug = true
  # Removed for Rails 4: config.assets.compress = false
    
  # Don't fallback to assets pipeline if a precompiled asset is missed
  # config.assets.compile = true
  # config.assets.digest = true
  # config.assets.initialize_on_precompile = false

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( collection.css collection.js injector.css injector.js )
  config.middleware.use ExceptionNotification::Rack,
    :email => {
      :email_prefix => "[RecipePower Failure!!] ",
      :sender_address => %{"notifier" <notifier@recipepower.com>},
      :exception_recipients => %w{recipepowerfeedback@gmail.com}
    }  

  config.action_mailer.delivery_method = :letter_opener # :smtp #

  config.eager_load = false # Added for Rails 4:

  # Use local, e.g. bootstrap, files rather than a CDN
  config.x.no_cdn = true
end
