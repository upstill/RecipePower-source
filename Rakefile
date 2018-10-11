#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# file = File.expand_path('../config/environment', __FILE__)
file = File.expand_path('../config/application', __FILE__)
puts "Loading #{file} from Rakefile"
require file
puts "Rails #{defined?(Rails) ? 'is' : 'is not'} defined"

module TempFixForRakeLastComment
  def last_comment
    last_description
  end
end
Rake::Application.send :include, TempFixForRakeLastComment

RP::Application.load_tasks

require 'rake/testtask'
require 'rdoc/task'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end
