=begin
load 'deploy'
# Uncomment if you are using Rails' asset pipeline
load 'deploy/assets'
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy' # remove this line to skip loading any of the default tasks
=end

# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

# Includes tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#
# require 'capistrano/rvm'
require 'capistrano/rbenv'
# require 'capistrano/chruby'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

after "deploy", "deploy:cleanup" # keep only the last 5 releases (rbates)

set :application, 'RP'

set :user, "upstill"

=begin
namespace :deploy do

  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command do
      on roles(:all) do # roles: :app, except: {no_release: true} do |host|
        execute "/etc/init.d/unicorn_#{application}", command
      end
    end
  end

  # This task should be run after first
  task :setup_config do
    on roles(:all) do |task|
      sudo "ln -nfs #{deploy_to}/current/config/nginx.conf /etc/nginx/sites-enabled/#{fetch :application}"
      sudo "ln -nfs #{deploy_to}/current/config/unicorn_init.sh /etc/init.d/unicorn_#{fetch :application}"
      execute "mkdir -p #{deploy_to}/shared/config"
      # put File.read("#{deploy_to}/current/config/database-example.yml"), "#{deploy_to}/shared/config/database.yml"
      unless test "[ -e #{deploy_to}/shared/config/database.yml ]"
        execute :cp, "#{deploy_to}/current/config/database-example.yml", "#{deploy_to}/shared/config/database.yml"
      end
      puts "Now edit the config files in #{deploy_to}/shared."
    end
  end
  after "deploy:symlink:release", "deploy:setup_config"

  task :symlink_config do
    on roles(:all) do |host|
      puts "Symlinking database.yml file on #{host}"
      sudo "ln -nfs #{deploy_to}/shared/config/database.yml #{deploy_to}/current/config/database.yml"
    end
  end
  after "deploy:setup_config", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:all) do |host|
      unless `git rev-parse HEAD` == `git rev-parse origin/staging`
        puts "WARNING: HEAD is not the same as origin/staging"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end
  after "deploy:started", "deploy:check_revision"

end
=end
