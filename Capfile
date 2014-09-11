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

namespace :deploy do

  # Begin rbates
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
      execute "[ ! -e #{deploy_to}/shared/config/database.yml ] && cp #{deploy_to}/current/config/database-example.yml #{deploy_to}/shared/config/database.yml"
      puts "Now edit the config files in #{deploy_to}/shared."
    end
  end
  # after "deploy:started", "deploy:setup_config"

  task :symlink_config do
    puts "In symlink_config, deploy_to is '#{deploy_to}'"
    on roles(:all) do |host|
      puts "Symlinking database.yml file on #{host}"
      sudo "ln -nfs #{deploy_to}/shared/config/database.yml #{deploy_to}/current/config/database.yml"
    end
  end
  after "deploy:published", "deploy:symlink_config"

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

  # End rbates

=begin
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, current_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within current_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
=end

end
