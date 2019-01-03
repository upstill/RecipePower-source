source 'http://rubygems.org'

ruby '2.3.6'
## gem 'bundler', '~> 1.4'
gem 'rails', '5.0.0'
gem 'rdoc'

###### Rails Extensions
# Protect attributes from mass-assignment in ActiveRecord models. (No longer supported in Rails 5)
## gem 'protected_attributes' # https://github.com/rails/protected_attributes
# Counter caches
gem 'counter_culture', '~> 0.1.23' # https://github.com/magnusvk/counter_culture
# TODO: implement categorization via Awesome Nested Set
gem 'awesome_nested_set' # https://github.com/collectiveidea/awesome_nested_set
# Forms made easy for Rails!
gem "simple_form", '~> 3.1' # https://github.com/plataformatec/simple_form
# Decorators/View-Models for Rails Applications
gem 'draper', '~> 3.0' #, ~> 1.3'
# Easily and efficiently make your ActiveRecord models support hierarchies
gem 'closure_tree', '~> 6.6' # https://github.com/mceachen/closure_tree
gem 'with_advisory_lock', '3.0'
# TODO Cache bit in each tag, for each taggable entity class, indicating that the tag is used.
## gem 'attr_bitwise' # https://github.com/wittydeveloper/attr_bitwise/
gem 'barkick' # Handle UPC codes, etc.

# Query interface https://robots.thoughtbot.com/using-arel-to-compose-sql-queries http://www.rubydoc.info/github/rails/arel
gem 'arel', '~> 7.0' # https://github.com/rails/arel

####### Ruby interface to PostgreSQL https://bitbucket.org/ged/ruby-pg/wiki/Home
gem 'pg', '0.20' # TODO: 1.0.0 for Rails 5
# Adds support for missing PostgreSQL data types to ActiveRecord.
# gem 'postgres_ext' # https://github.com/jagregory/postgres_ext
## gem 'pg_search' # For full-text search https://robots.thoughtbot.com/optimizing-full-text-search-with-postgres-tsvector-columns-and-triggers
#### Full-text search with Elasticsearch: https://github.com/elastic/elasticsearch-rails
# See also https://18f.gsa.gov/2016/04/08/how-we-get-high-availability-with-elasticsearch-and-ruby-on-rails/
## gem 'elasticsearch-model', github: 'elastic/elasticsearch-rails', branch: '5.x'
## gem 'elasticsearch-rails', github: 'elastic/elasticsearch-rails', branch: '5.x'

# Makes running your Rails app easier. Based on the ideas behind http://12factor.net/
gem 'rails_12factor', :group => [ :production, :staging ] # https://github.com/heroku/rails_12factor

# Use unicorn as the web server
gem 'unicorn'
gem 'unicorn-rails'

# Server
gem 'thin'

# Activity Notification
gem 'activity_notification', '1.4.4', :path => 'vendor/gems/activity_notification-1.4.4'

####### JQuery, Coffeescript and Bootstrap
gem 'jquery-rails', '~> 4.1.0' # '~> 4.2.0' # '~> 4.3.3' # ~> 4.0' # '2.2.1' to get jQuery 1.9.1
## gem 'jquery-rails-google-cdn'
gem 'jquery-ui-rails', '~> 3.0'
gem 'coffee-rails', "~> 4.2"
gem 'uglifier', '>= 1.3.0'
## gem 'compass-rails'
gem 'sass-rails', " ~> 5.0"
gem 'bootstrap-sass', '~> 3.3.4' # '~> 3.1.1'
## gem 'bootstrap-sass', github: 'thomas-mcdonald/bootstrap-sass', branch: '3'
gem 'autoprefixer-rails'
# gem 'jquery-migrate-rails' # TODO: remove after jQuery 1.9 is confirmed  https://jquery.com/upgrade-guide/1.9/
gem 'masonry-rails'
gem 'jquery-fileupload-rails', '0.4.7'
gem 'sassc', '~> 1.12' # Version 2.0 requires Ruby 2.3

###### Authentication and authorization
gem 'devise', '~> 4.0'                       # auth, rails generate devise:install, rails generate devise MODEL
gem 'devise_invitable', '~> 1.6' # git: 'git://github.com/scambra/devise_invitable.git'
gem 'ruby-openid'
gem 'omniauth-twitter'
gem 'omniauth-facebook', '~> 4.0.0'
gem 'omniauth-google-oauth2'
gem 'omniauth-openid'
gem 'declarative_authorization', git: 'http://github.com/stffn/declarative_authorization.git'     # simple auth rules/roles, create config/authorization_rules.rb, add filter_resource_access to each controller, use permitted_to? in views

###### Essential Ruby libs
gem "rmagick", "~> 2.16.0"
gem "feedjira", '~> 1.6' #:git => 'git://github.com/pauldix/feedzirra.git'
gem 'nokogiri', "~> 1.6.6" # "~> 1.5.3"
gem 'truncato'  # Truncates HTML strings, respecting tags https://github.com/jorgemanrubia/truncato
# Redcarpet is a Ruby library for Markdown processing that smells like butterflies and popcorn.
gem 'redcarpet' # https://github.com/vmg/redcarpet

###### Worker management
gem 'delayed_job', git: 'git://github.com/collectiveidea/delayed_job.git'
gem 'delayed_job_active_record', git: 'git://github.com/collectiveidea/delayed_job_active_record.git'
gem 'daemons' # Per DelayedJob documentation
gem 'hirefire-resource'

###### Deploy with Capistrano
gem 'sshkit', '~> 1.3.0'
gem 'net-ssh', '~> 2.9'
gem 'capistrano', '~> 3.3.5'
gem 'capistrano-rails', '~> 1.1.2'
gem 'capistrano-bundler', '~> 1.1.4'
gem 'capistrano-rbenv', '~> 2.0.3'

###### External interfaces
# Extract Pocket/Readability page data into PageRefs
gem 'mechanize', :group => [ :development, :staging ]
gem 'youtube_addy' # Embed YouTube videos
## gem 'active_model_serializers'
gem 'aws-sdk', '~> 1' # Keep thumbnails using AWS as CDN
# Sugg. on StackOverflow to use master right-aws: gem 'right_aws', :git => 'git://github.com/rightscale/right_aws.git'

## gem 'letsencrypt_plugin'

group :production do
  gem 'dalli'
end

group :development do
  ## gem 'minitest', '~> 4.2'
  gem 'annotate', '2.5.0'
  gem "nifty-generators"
  gem 'log_buddy'
  ## gem 'ruby-prof' # , '~> 0.13.0' # , :git => 'git://github.com/wycats/ruby-prof.git'
  ## gem "better_errors" '~> 1.1'
  gem "binding_of_caller"
  ## gem "json"
  gem 'rack-mini-profiler', '~> 0.10'  # Subsequent versions require Ruby 2.3
  gem 'derailed'
  gem 'heapy', '0.1.1' # Subsequent versions require Ruby 2.3
  gem 'stackprof'
  gem 'flamegraph'
end

# Stack trace on errors
gem 'exception_notification', git: 'git://github.com/smartinez87/exception_notification.git'
## gem 'exception_notification', '~> 4.0.1', :require => 'exception_notifier' # , git: 'git://github.com/alanjds/exception_notification.git'

# Report errors via email
gem 'letter_opener', :group => [ :development, :staging ]
gem 'letter_opener_web', '~> 1.3.4', :group => :staging

###### Performance testing   http://railscasts.com/episodes/411-performance-testing?view=asciicast
gem 'rails-perftest' # https://github.com/rails/rails-perftest
gem 'ruby-prof' # https://github.com/ruby-prof/ruby-prof

group :test do
  ## gem 'minitest-rails' # , "~> 1.0" ## gem 'minitest', '~> 4.2'
  ## gem "minitest-rails-capybara" # ...for simulating user interaction
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'webrat', '~> 0.7.3'
  ### gem "guard-rspec" # ...for auto-running tests on file save  http://railscasts.com/episodes/264-guard?view=asciicast
  gem 'factory_bot_rails' # 'factory_girl_rails', "~> 4.0"
  gem "mocha"
  gem 'poltergeist'
  gem 'rspec-rails', '3.8.1'
  gem 'rspec-html-matchers', '0.9.1'
end

###### TODO are these even being used?

# Enables use of content_for in your controllers
gem 'content_for_in_controllers' # https://github.com/clm-a/content_for_in_controllers

# Bourbon is a library of Sass mixins and functions that are designed to make you a more efficient style sheet author.
gem 'bourbon' # https://github.com/thoughtbot/bourbon

# CSS styled emails without the hassle.
gem 'premailer-rails' # https://github.com/fphilipe/premailer-rails

# EventMachine is an event-driven I/O and lightweight concurrency library for Ruby
gem 'eventmachine', '~> 1.0.3' # https://github.com/eventmachine/eventmachine

# ruby_parser (RP) is a ruby parser written in pure ruby
gem 'ruby_parser' # https://github.com/seattlerb/ruby_parser

# Observer classes respond to life cycle callbacks to implement trigger-like behavior outside the original class.
# Alternatives? Concerns. http://stackoverflow.com/questions/15165260/rails-observer-alternatives-for-4-0
gem 'rails-observers' # https://github.com/rails/rails-observers

# Builder provides a number of builder objects that make creating structured data simple to do.
gem 'builder', '~> 3.1.0' # https://rubygems.org/gems/builder/versions/3.2.2

# A module for encoding and decoding (X)HTML entities.
gem 'htmlentities'  # https://rubygems.org/gems/htmlentities/versions/4.3.4

# Pagination library (TODO: almost certainly defunct)
gem 'will_paginate', '~> 3.0'  # https://github.com/mislav/will_paginate
## gem 'actionpack-page_caching'
## gem 'actionpack-action_caching'
