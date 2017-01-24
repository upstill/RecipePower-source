source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.7.1'
# Use sqlite3 as the database for Active Record
gem 'sqlite3'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'rails-perftest', group: :test
gem 'ruby-prof', group: :test

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

# Re-added gems, in order:
ruby '2.2.0'
gem 'aws-sdk', '~> 1'
gem 'delayed_job', git: 'git://github.com/collectiveidea/delayed_job.git'
gem 'delayed_job_active_record', git: 'git://github.com/collectiveidea/delayed_job_active_record.git'

gem 'pg'

gem 'devise', '~> 3.4.0'                       # auth, rails generate devise:install, rails generate devise MODEL
gem 'devise_invitable', '~> 1.3.0' # git: 'git://github.com/scambra/devise_invitable.git'

gem 'hirefire-resource'

gem 'ruby-openid'
gem 'omniauth-twitter'
gem 'omniauth-facebook' # , '~> 1.4.0'
gem 'omniauth-google-oauth2'
gem 'omniauth-openid'
gem 'declarative_authorization', '~> 0.5.7'     # simple auth rules/roles, create config/authorization_rules.rb, add filter_resource_access to each controller, use permitted_to? in views

gem "simple_form", '~> 3.1' # , :git => 'git://github.com/plataformatec/simple_form.git' #

gem 'redcarpet'

gem 'counter_culture', '~> 0.1.23'

gem 'protected_attributes'

gem 'composite_primary_keys', '~> 8.0'

gem 'htmlentities'

gem "rmagick", "~> 2.13.2"

gem 'mechanize', :group => [ :development, :staging ]

gem "feedjira", '~> 1.6' #:git => 'git://github.com/pauldix/feedzirra.git'

gem 'jquery-migrate-rails' # TODO: remove after jQuery 1.9 is confirmed

gem 'jquery-ui-rails', '~> 3.0'

gem 'bourbon'

gem 'bootstrap-sass', '~> 3.3.4' # '~> 3.1.1'

# gem 'nokogiri', '~> 1.7.0' # "~> 1.6.6" # "~> 1.5.3"

# gem 'rails', '~> 4.2.5' # '3.2.11' #
# gem 'arel', '~> 6.0'
# gem 'postgres_ext'
# gem 'rails_12factor', :group => [ :production, :staging ]
# gem 'rails-perftest'
# gem 'ruby-prof'
#
# gem 'thin'
#
# # add these gems to help with the transition:
# gem 'rails-observers'
#
# # Bundle edge Rails instead:
#
#
# gem 'builder', '~> 3.1.0'
# gem 'draper', '~> 1.3'
# gem 'closure_tree'
# gem 'will_paginate', '~> 3.0'
# gem 'newrelic_rpm'
# # Sugg. on StackOverflow to use master right-aws: gem 'right_aws', :git => 'git://github.com/rightscale/right_aws.git'
# gem 'eventmachine', '~> 1.0.3'
# gem 'ruby_parser'
# gem 'daemons'
# gem 'awesome_nested_set'
# gem 'content_for_in_controllers'
# gem 'youtube_addy'
# gem 'letter_opener', :group => [ :development, :staging ]
# gem 'letter_opener_web', '~> 1.2.0', :group => :staging
# gem 'rspec-rails', '2.99', :group => [ :development, :test ] # ~> 3.1'
# gem 'premailer-rails'
#
# gem 'exception_notification', git: 'git://github.com/smartinez87/exception_notification.git'
#
# gem "masonry-rails"
#
# gem 'coffee-rails', "~> 4.0.0"
# gem 'uglifier', '>= 1.3.0'
# gem 'sass-rails', " ~> 4.0"
# gem 'autoprefixer-rails'
#
# gem 'jquery-rails', '~> 4.0.3'
#
# # Use unicorn as the web server
# gem 'unicorn'
# gem 'unicorn-rails'
#
# # Deploy with Capistrano
# gem 'sshkit', '~> 1.3.0'
# gem 'capistrano', '~> 3.3.5'
# gem 'capistrano-rails', '~> 1.1.2'
# gem 'capistrano-bundler', '~> 1.1.4'
# gem 'capistrano-rbenv', '~> 2.0.3'
#
# group :development do
#   gem 'annotate', '2.5.0'
#   gem "nifty-generators"
#   gem 'log_buddy'
#   gem "binding_of_caller"
#   gem 'rack-mini-profiler'
#   gem 'derailed'
#   gem 'stackprof'
#   gem 'flamegraph'
# end
#
# group :test do
#   # gem 'minitest-rails' # , "~> 1.0" # gem 'minitest', '~> 4.2'
#   # gem "minitest-rails-capybara" # ...for simulating user interaction
#   # Pretty printed test output
#   gem 'turn', :require => false
#   gem 'webrat', '~> 0.7.3'
#   ## gem "guard-rspec" # ...for auto-running tests on file save
#   gem 'factory_girl_rails', "~> 4.0"
#   gem "mocha"
#   gem 'poltergeist'
# end
#
