RP::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  # config.assets.js_compressor = :uglifier

  # Don't fallback to assets pipeline if a precompiled asset is missed
  # On by default in R4: config.assets.compile = true
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( collection.css collection.js injector.css injector.js )

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # config.logger = Logger.new(STDOUT)
  # config.logger.level = Logger::DEBUG # use logger.level, not log_level

  # See everything in the log (default is :info)
  config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { :host => 'www.recipepower.com' }
  
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    :address              => ENV['MAILGUN_SMTP_SERVER'],
    :port                 => ENV['MAILGUN_SMTP_PORT'],
    :domain               => 'strong-galaxy-5765-74.herokuapp.com',
    :user_name            => ENV['MAILGUN_SMTP_LOGIN'],
    :password             => ENV['MAILGUN_SMTP_PASSWORD'],
    :authentication       => 'plain',
    :enable_starttls_auto => true  
  }
=begin
  ActionMailer::Base.smtp_settings = {
    :address        => ENV['MAILGUN_SMTP_SERVER'],
    :port           => ENV['MAILGUN_SMTP_PORT'], 
    :authentication => :plain,
    :domain         => 'strong-galaxy-5765.heroku.com',
    :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
    :password       => ENV['MAILGUN_SMTP_PASSWORD'],
  }
=end

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    :address              => ENV['MAILGUN_SMTP_SERVER'],
    :port                 => ENV['MAILGUN_SMTP_PORT'],
    :domain               => 'strong-galaxy-5765-74.herokuapp.com',
    :user_name            => ENV['MAILGUN_SMTP_LOGIN'],
    :password             => ENV['MAILGUN_SMTP_PASSWORD'],
    :authentication       => 'plain',
    :enable_starttls_auto => true  
  }
=begin
  ActionMailer::Base.smtp_settings = {
    :address        => ENV['MAILGUN_SMTP_SERVER'],
    :port           => ENV['MAILGUN_SMTP_PORT'], 
    :authentication => :plain,
    :domain         => 'strong-galaxy-5765.heroku.com',
    :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
    :password       => ENV['MAILGUN_SMTP_PASSWORD'],
  }
=end

  # Enable threaded mode
  # config.threadsafe!
  
  config.eager_load = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  config.middleware.use ExceptionNotification::Rack,
    :email => {
      :email_prefix => "[RecipePower Failure!!] ",
      :sender_address => %{"notifier" <upstill@gmail.com>},
      :exception_recipients => %w{recipepowerfeedback@gmail.com}
    }  
=begin
  config.middleware.use ExceptionNotification,
    :email_prefix => "[RecipePower Failure!!] ",
    :sender_address => %{"notifier" <upstill@gmail.com>},
    :exception_recipients => %w{recipepowerfeedback@gmail.com},
    :ignore_exceptions => ExceptionNotification.default_ignore_exceptions # + [RunTimeError]
=end

  ActionMailer::Base.delivery_method = :smtp
end
