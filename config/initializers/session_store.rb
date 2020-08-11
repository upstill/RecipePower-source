# Be sure to restart your server when you modify this file.

domain =
    case
      when Rails.env.production?
        'www.recipepower.com'
      when Rails.env.staging?
        'staging.recipepower.com'
      else
        'local.recipepower.com'
    end
RP::Application.config.session_store :cookie_store,
                                     key: '_rp_session',
                                     :domain => domain,
                                     :secure => true,
                                     :expire_after => 7.days

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# RP::Application.config.session_store :active_record_store
