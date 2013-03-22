source 'http://rubygems.org'

gem 'rails', '3.2.11'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

gem 'pg'

gem 'closure_tree'
gem 'htmlentities'
gem 'nokogiri'
gem 'will_paginate', '~> 3.0'
gem 'minitest'
gem 'newrelic_rpm'
gem 'devise'                        # auth, rails generate devise:install, rails generate devise MODEL
gem 'devise_invitable'
gem 'ruby-openid'
gem 'omniauth-twitter'                      
gem 'omniauth-facebook'                     
gem 'omniauth-google-oauth2'                     
gem 'omniauth-openid'                     
gem 'declarative_authorization'     # simple auth rules/roles, create config/authorization_rules.rb, add filter_resource_access to each controller, use permitted_to? in views
gem 'thin'
gem 'eventmachine', '1.0.0.rc.4'
gem 'ruby_parser'
gem "rmagick", "2.12.0", :require => 'RMagick'
gem "feedzirra"
gem "simple_form"
gem 'delayed_job_active_record'
gem 'hirefire-resource'

# gem 'exception_notification', :require => 'exception_notifier'
gem 'exception_notification', :require => 'exception_notifier', git: 'git://github.com/alanjds/exception_notification.git' 
group :development do
  gem 'rspec-rails', '2.6.1'
  gem 'annotate', '2.4.0'
  gem "nifty-generators"
  gem 'debugger'
  gem 'log_buddy'
  gem 'ruby-prof', :git => 'git://github.com/wycats/ruby-prof.git'
  gem 'letter_opener'
  gem "better_errors"
  gem "binding_of_caller"
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails', "~> 3.2.1"
  gem 'uglifier', '>= 1.0.3'
  gem 'compass-rails'
  gem 'sass-rails', " ~> 3.2.3"
  gem 'bootstrap-sass', '~> 2.2.2.0'
end

gem 'jquery-rails'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'rspec-rails', '2.6.1'
  gem 'debugger'
  gem 'webrat', '0.7.1'
end

gem "mocha", :group => :test
