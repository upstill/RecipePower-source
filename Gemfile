source 'http://rubygems.org'

ruby '1.9.3'
gem 'rails', '~> 4.0' # '3.2.11' #
# gem 'rails',     :git => 'git://github.com/rails/rails.git'
# gem 'rails4_upgrade'
gem 'rails_12factor', :group => [ :production, :staging ]

# add these gems to help with the transition:
gem 'protected_attributes'
gem 'rails-observers'  
# gem 'actionpack-page_caching'
# gem 'actionpack-action_caching'

# Bundle edge Rails instead:

gem 'pg'

gem 'builder', '~> 3.1.0'
gem 'draper', '~> 1.3'
gem 'closure_tree'
gem 'htmlentities'
gem 'nokogiri', "~> 1.5" # "~> 1.5.3"
gem 'will_paginate', '~> 3.0'
gem 'newrelic_rpm'
# Sugg. on StackOverflow to use master right-aws: gem 'right_aws', :git => 'git://github.com/rightscale/right_aws.git'
gem 'devise', '~> 3.1.0'                       # auth, rails generate devise:install, rails generate devise MODEL
gem 'devise_invitable', '~> 1.3.0' # git: 'git://github.com/scambra/devise_invitable.git'
gem 'ruby-openid'
gem 'omniauth-twitter'                      
gem 'omniauth-facebook' # , '~> 1.4.0'
gem 'omniauth-google-oauth2'                     
gem 'omniauth-openid'                     
gem 'declarative_authorization'     # simple auth rules/roles, create config/authorization_rules.rb, add filter_resource_access to each controller, use permitted_to? in views
gem 'eventmachine', '~> 1.0.3'
gem 'ruby_parser'
gem "rmagick", "~> 2.13.2"
gem "feedzirra", "~> 0.2" # :git => 'git://github.com/pauldix/feedzirra.git'
gem "simple_form", :git => 'git://github.com/plataformatec/simple_form.git' # , '~> 3.0.0.beta1' 
gem 'delayed_job' # , git: 'git://github.com/collectiveidea/delayed_job.git'
gem 'delayed_job_active_record' # , git: 'git://github.com/collectiveidea/delayed_job_active_record.git'
gem 'daemons'
gem 'hirefire-resource'
# gem 'debugger', :group => [:test, :development]
gem 'awesome_nested_set'
gem 'redcarpet'
gem 'content_for_in_controllers'
gem 'youtube_addy'
# gem 'active_model_serializers'

gem 'exception_notification', git: 'git://github.com/smartinez87/exception_notification.git'
# gem 'exception_notification', '~> 4.0.1', :require => 'exception_notifier' # , git: 'git://github.com/alanjds/exception_notification.git' 
group :development do
  gem 'minitest', '~> 4.2'
  # gem 'rspec-rails'
  gem 'annotate', '2.5.0'
  gem "nifty-generators"
  gem 'log_buddy'
  gem 'ruby-prof', '~> 0.13.0' # , :git => 'git://github.com/wycats/ruby-prof.git'
  gem 'letter_opener'
  gem "better_errors"
  gem "binding_of_caller"
  # gem "json"
end

gem "masonry-rails"

group :test do
  gem 'minitest-rails', "~> 1.0" # gem 'minitest', '~> 4.2'
  # gem 'rspec-rails'
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'webrat', '~> 0.7.3'
  gem "minitest-rails-capybara" # ...for simulating user interaction
  # gem "guard-rspec" # ...for auto-running tests on file save
  gem 'factory_girl_rails', "~> 4.0"
  gem "mocha"
  gem 'poltergeist'
end

gem 'coffee-rails', "~> 4.0.0"
gem 'uglifier', '>= 1.3.0'
# gem 'compass-rails'
gem 'sass-rails', " ~> 4.0"
gem 'bootstrap-sass', '~> 3.2.0' # '~> 3.1.1'
# gem 'bootstrap-sass', github: 'thomas-mcdonald/bootstrap-sass', branch: '3'
gem 'autoprefixer-rails'

gem 'jquery-rails'

# Use unicorn as the web server
gem 'unicorn'
gem 'unicorn-rails'

# Deploy with Capistrano
gem 'sshkit', '~> 1.3.0'
gem 'capistrano'
gem 'capistrano-rails'
gem 'capistrano-bundler'
gem 'capistrano-rbenv'
# gem 'capistrano-rvm'

