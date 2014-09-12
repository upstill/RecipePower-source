# config valid only for Capistrano 3.1
lock '3.2.1'

require "./config/recipes/base"
require "./config/recipes/nginx"
require "./config/recipes/unicorn"
require "./config/recipes/postgresql"
require "./config/recipes/nodejs"
require "./config/recipes/rbenv"
require "./config/recipes/check"

set :application, 'RP'

set :user, "upstill"

set :repo_url, 'git@github.com:upstill/RecipePower-source.git'

# Default branch is :master
set :branch, :staging # ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# See Railscasts 337
set :deploy_via, :remote_cache

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, "/home/upstill/apps/#{application}"
# set :deploy_to, "/home/upstill/apps/RP"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

set :rbenv_ruby, '1.9.3-p286'
set :rbenv_type, :user # or :system, depends on your rbenv setup
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
set :rbenv_roles, :all # default value
