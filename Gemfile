source 'http://rubygems.org'

ruby '1.9.3'
gem 'rails', '4.0.0' # '3.2.11' #
gem 'rails4_upgrade'

# add these gems to help with the transition:
gem 'protected_attributes'
gem 'rails-observers'
gem 'actionpack-page_caching'
gem 'actionpack-action_caching'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

gem 'pg'

gem 'closure_tree'
gem 'htmlentities'
gem 'nokogiri', "~> 1.5.10"
gem 'will_paginate', '~> 3.0'
gem 'minitest'
gem 'newrelic_rpm'
gem 'devise'                        # auth, rails generate devise:install, rails generate devise MODEL
gem 'devise_invitable'
gem 'ruby-openid'
gem 'omniauth-twitter'                      
gem 'omniauth-facebook', '1.4.0'                     
gem 'omniauth-google-oauth2'                     
gem 'omniauth-openid'                     
gem 'declarative_authorization'     # simple auth rules/roles, create config/authorization_rules.rb, add filter_resource_access to each controller, use permitted_to? in views
gem 'thin'
gem 'eventmachine', '1.0.0.rc.4'
gem 'ruby_parser'
gem "rmagick", "2.12.0", :require => 'RMagick'
gem "feedzirra"
gem "simple_form", :git => 'git://github.com/plataformatec/simple_form.git'
gem 'delayed_job', git: 'git://github.com/collectiveidea/delayed_job.git'
gem 'delayed_job_active_record', git: 'git://github.com/collectiveidea/delayed_job_active_record.git'
# gem 'delayed_job_active_record'
gem 'hirefire-resource'
gem 'rspec-rails', :group => [:test, :development]
gem 'debugger', :group => [:test, :development]
gem 'awesome_nested_set'
gem 'redcarpet'
gem 'content_for_in_controllers'

# gem 'exception_notification', :require => 'exception_notifier'
gem 'exception_notification', :require => 'exception_notifier', git: 'git://github.com/alanjds/exception_notification.git' 
group :development do
  gem 'annotate', '2.4.0'
  gem "nifty-generators"
  gem 'log_buddy'
  gem 'ruby-prof', :git => 'git://github.com/wycats/ruby-prof.git'
  gem 'letter_opener'
  gem "better_errors"
  gem "binding_of_caller"
end

gem "masonry-rails"

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'webrat', '0.7.1'
  # gem "capybara" # ...for simulating user interaction
  # gem "guard-rspec" # ...for auto-running tests on file save
end

# Gems used only for assets and not required
# in production environments by default.
gem 'coffee-rails', "~> 4.0.0"
gem 'uglifier', '>= 1.3.0'
gem 'compass-rails'
gem 'sass-rails', " ~> 4.0.0.rc1"
gem 'bootstrap-sass', '~> 2.2.2.0'

gem 'jquery-rails'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

gem "mocha", :group => :test
