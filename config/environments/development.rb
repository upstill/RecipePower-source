RP::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # See everything in the log (default is :info)
  config.log_level = :debug

  # Log error messages when you accidentally call methods on nil.
  # Obsolete in Rails 4: config.whiny_nils = true 

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true # false
  config.action_mailer.default_url_options = { :host => 'local.recipepower.com:3000' }
  
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
  # TODO When we're sure that SSL works
  config.force_ssl = true

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( collection.css collection.js injector.css injector.js )
  config.middleware.use ExceptionNotification::Rack,
    :email => {
      :email_prefix => "[RecipePower Failure!!] ",
      :sender_address => %{"notifier" <notifier@recipepower.com>},
      :exception_recipients => %w{recipepowerfeedback@gmail.com}
    }  
=begin
  config.middleware.use ExceptionNotification,
    :email_prefix => "[RecipePower Failure!!] ",
    :sender_address => %{"notifier" <notifier@recipepower.com>},
    :exception_recipients => %w{recipepowerfeedback@gmail.com}
=end

  config.action_mailer.delivery_method = :letter_opener # :smtp

  config.eager_load = false # Added for Rails 4: 
end
