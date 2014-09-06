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
application = "RP"
current_path = "/home/upstill/apps/RP/current"
shared_path = "/home/upstill/apps/RP/shared"
release_path = "/home/upstill/apps/RP/current"

namespace :deploy do
  # Begin rbates
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command do
      on :app do |host| # roles: :app, except: {no_release: true} do |host|
        run "/etc/init.d/unicorn_#{application} #{command}"
      end
    end
  end

  task :setup_config do
    on :app do |task|
      sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
      sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
      run "mkdir -p #{shared_path}/config"
      put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
      puts "Now edit the config files in #{shared_path}."
    end
  end
  # after "deploy:setup", "deploy:setup_config"

  task :symlink_config do
    on :app do
      run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end
  end
  # after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on :web do |host|
      unless `git rev-parse HEAD` == `git rev-parse origin/staging`
        puts "WARNING: HEAD is not the same as origin/staging"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end
  before "deploy", "deploy:check_revision"
  # End rbates

=begin
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
=end

end
