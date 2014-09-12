set :postgresql_host, "localhost"
set :postgresql_user, "upstill"
set :postgresql_password, ask("PostgreSQL Password: ") # Capistrano::CLI.password_prompt("PostgreSQL Password: ")
set :postgresql_database, "cookmarks_production" 

namespace :postgresql do
  desc "Install the latest stable release of PostgreSQL."
  task :install do # , roles: :db, only: {primary: true} do
    on roles(:db) do
      sudo "add-apt-repository ppa:pitti/postgresql"
      sudo "apt-get -y update"
      sudo "apt-get -y install postgresql libpq-dev"
    end
  end
  after "deploy:install", "postgresql:install"

  desc "Create a database for this application."
  task :create_database do # , roles: :db, only: {primary: true} do
    on roles(:db) do
      sudo %Q{-u postgres psql -c "create user #{postgresql_user} with password '#{postgresql_password}';"}
      sudo %Q{-u postgres psql -c "create database #{postgresql_database} owner #{postgresql_user};"}
    end
  end
  # after "deploy:setup", "postgresql:create_database"
  after "deploy:published", "postgresql:create_database"

  desc "Generate the database.yml configuration file."
  task :setup do # , roles: :app do
    on roles(:app) do
      sudo "mkdir -p #{shared_path}/config"
      template "postgresql.yml.erb", "#{shared_path}/config/database.yml"
    end
  end
  # after "deploy:setup", "postgresql:setup"
  after "deploy:published", "postgresql:setup"

  desc "Symlink the database.yml file into latest release"
  task :symlink do # , roles: :app do
    on roles(:app) do
      sudo "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    end
  end
  # after "deploy:finalize_update", "postgresql:symlink"
  after "deploy:published", "postgresql:symlink"
end
