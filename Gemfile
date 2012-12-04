source 'http://rubygems.org'

gem 'rails', '3.2.0'

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

# gem 'exception_notification', :require => 'exception_notifier'
gem 'exception_notification', :require => 'exception_notifier', git: 'git://github.com/alanjds/exception_notification.git' 
group :development do
  gem 'rspec-rails', '2.6.1'
  gem 'annotate', '2.4.0'
  gem "nifty-generators"
  # To use debugger (ruby-debug for Ruby 1.8.7+, ruby-debug19 for Ruby 1.9.2+)
  # gem 'ruby-debug'
  gem 'debugger'
  # gem 'ruby-debug19', :require => 'ruby-debug'
  gem 'log_buddy'
  gem 'ruby-prof', :git => 'git://github.com/wycats/ruby-prof.git'
  gem 'letter_opener'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', " ~> 3.2.3"
  gem 'coffee-rails', "~> 3.2.1"
  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'rspec-rails', '2.6.1'
  gem 'debugger'
  # gem 'ruby-debug19', :require => 'ruby-debug'
  gem 'webrat', '0.7.1'
end

gem "mocha", :group => :test
