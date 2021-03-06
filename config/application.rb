require File.expand_path('../boot', __FILE__)

require 'rails/all'

class ActionController::Base
  # Declare the defunct #hide_action class method for the benefit of DeclarativeAuthorization
  def self.hide_action *args
  end
end

# puts (["Loading Bundler in #{__FILE__}. Backtrace:"] + caller).join("\n  >> ")
Bundler.require(:default, Rails.env)
# puts "Finished loading Bundler in #{__FILE__}."
# puts

module RP
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(
    #{config.root}/app/models/concerns
      #{config.root}/app/services
      #{config.root}/app/presenters
      #{config.root}/app/mixins
      #{config.root}/lib
      #{config.root}/app/controllers/cmods
    )
    # require class extensions right now
    Dir[Rails.root.join('app', 'extensions', "*.rb")].each { |l| require l }

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = false
    config.i18n.fallbacks = true

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable the asset pipeline (on by default)
    # config.assets.enabled = true

    # config.active_record.raise_in_transactional_callbacks = true

    # Issue CSRF credentials for every form
    config.action_controller.per_form_csrf_tokens = true

    # Check if the HTTP Origin header should be checked against the site's origin
    config.action_controller.forgery_protection_origin_check = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.enabled = true
    config.assets.version = '1.0'

    # Devise suggests the following
    # If you are deploying Rails 3.1 on Heroku, you may want to set:
    config.assets.initialize_on_precompile = false
    # On config/application.rb forcing your application to not access the DB
    # or load models when precompiling your assets.

    # Handle jquery through a CDN (optionally)
    # config.assets.precompile += ["jquery.min.js"]
    config.use_jquery2 = true

    config.active_job.queue_adapter = :delayed_job

    # Make sure all requests to recipepower.com go to www.recipepower.com
    config.middleware.insert_before(Rack::Runtime, Rack::Rewrite) do
      r301 %r{.*}, 'http://www.recipepower.com$&', :if => Proc.new {|rack_env|
        rack_env['SERVER_NAME'] == 'recipepower.com'
      }
    end
  end
end
