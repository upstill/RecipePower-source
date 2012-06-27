source 'http://rubygems.org'

gem 'rails', '3.1.0'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# gem 'sqlite3'

# Gems for the Tutorial sample app
gem 'pg'

gem 'closure_tree'
gem 'htmlentities'
gem 'nokogiri'
gem 'will_paginate', '~> 3.0'
gem 'minitest'
gem 'newrelic_rpm'
gem 'devise'                        # auth, rails generate devise:install, rails generate devise MODEL
gem 'devise_invitable'
gem 'omniauth-twitter'                      
gem 'omniauth-facebook'                     
gem 'omniauth-google-oauth2'                     
gem 'declarative_authorization'     # simple auth rules/roles, create config/authorization_rules.rb, add filter_resource_access to each controller, use permitted_to? in views

group :development do
  gem 'rspec-rails', '2.6.1'
  gem 'annotate', '2.4.0'
  gem "nifty-generators"
  # To use debugger (ruby-debug for Ruby 1.8.7+, ruby-debug19 for Ruby 1.9.2+)
  # gem 'ruby-debug'
  gem 'ruby-debug19', :require => 'ruby-debug'
  gem 'log_buddy'
  gem 'ruby-prof', :git => 'git://github.com/wycats/ruby-prof.git'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "  ~> 3.1.0"
  gem 'coffee-rails', "~> 3.1.0"
  gem 'uglifier'
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
  gem 'ruby-debug19', :require => 'ruby-debug'
  gem 'webrat', '0.7.1'
end

gem "mocha", :group => :test
