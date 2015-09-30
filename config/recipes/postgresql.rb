set :postgresql_host, "localhost"
set :postgresql_port, '5432'
set :postgresql_user, "upstill"
set :postgresql_pgpass, "/home/#{fetch :postgresql_user}/.pgpass"
set :postgresql_password, ask("PostgreSQL Password: ", nil) # Capistrano::CLI.password_prompt("PostgreSQL Password: ")
set :postgresql_database, "cookmarks_production"
set :heroku_app, "strong-galaxy-5765"
set :postgresql_dburl, `heroku pg:backups public-url --app #{fetch :heroku_app}`.chomp

namespace :postgresql do
  desc "Install the latest stable release of PostgreSQL."
  task :install do # , roles: :db, only: {primary: true} do
    on roles(:db) do
      sudo "add-apt-repository --yes ppa:pitti/postgresql"
      sudo "apt-get -y update"
      sudo "apt-get -y install postgresql libpq-dev"
    end
  end
  after "deploy:install", "postgresql:install"

  desc "Create a database for this application."
  task :create_database do # , roles: :db, only: {primary: true} do
    on roles(:db) do
=begin
Couldn't figure out how to use sudo with another user
      sudo %Q{-u postgres psql -c "create user #{fetch :postgresql_user} with password '#{fetch :postgresql_password}';"}
      sudo %Q{-u postgres psql -c "create database #{fetch :postgresql_database} owner #{fetch :postgresql_user};"}
=end
      if test("[ ! -e #{fetch :postgresql_pgpass} ]") # Build the database only if there's no .pgpass file
        sudo %Q{-u postgres psql -c "create user #{fetch :postgresql_user} with password '#{fetch :postgresql_password}';" ; true}
        sudo %Q{-u postgres psql -c "create database #{fetch :postgresql_database} owner #{fetch :postgresql_user};" ; true}
        template "pgpass.erb", fetch(:postgresql_pgpass)
        execute "chmod 0600 #{fetch :postgresql_pgpass}"
      end
    end
  end
  # after "deploy:setup", "postgresql:create_database"
  before "deploy:migrate", "postgresql:create_database"

  desc "Get the database from Heroku"
  task :fetch_database do # , roles: :db, only: {primary: true} do
    on roles(:db) do
      def run_and_show str
        output =  `#{str}`.chomp
        info "'#{str}'\n\t=> (#{$?.to_s})\n\t'#{output}'"
        output
      end
      # sudo "curl --silent -o /tmp/latest.dump '#{fetch :postgresql_dburl}'"
      # execute "pg_restore --no-password --verbose --clean --no-acl --no-owner -h #{fetch :postgresql_host} -U #{fetch :postgresql_user} -d #{fetch :postgresql_database} /tmp/latest.dump ; true"
      run_and_show 'whoami'
      run_and_show '/usr/bin/heroku --version'
      run_and_show 'echo $AWS_ACCESS_KEY_ID'
      dburl = run_and_show "heroku pg:backups public-url --app strong-galaxy-5765"
      # NB: since the Heroku toolbelt doesn't work in this context, it's necessary to provide the backup url
      # in dburl, eg., run the command elsewhere and set the result here
      # As it stands, the database will NOT be replaced unless dburl is set explicitly
      if dburl.length > 0
        execute "curl --silent '#{dburl}' | pg_restore --no-password --verbose --clean --no-acl --no-owner -h #{fetch :postgresql_host} -U #{fetch :postgresql_user} -d #{fetch :postgresql_database} ; true"
      end
    end
  end
  after "postgresql:create_database", "postgresql:fetch_database"

  desc "Generate the database.yml configuration file."
  task :setup do # , roles: :app do
    on roles(:app) do
      execute "mkdir -p #{shared_path}/config"
      template "postgresql.yml.erb", "#{shared_path}/config/database.yml"
    end
  end
  # after "deploy:setup", "postgresql:setup"
  after "postgresql:fetch_database", "postgresql:setup"

  desc "Symlink the database.yml file into latest release"
  task :symlink do # , roles: :app do
    on roles(:app) do
      # Link the database config file to the most recent (i.e., current) release
      execute "ln -nfs #{shared_path}/config/database.yml `ls -t -d -1 #{deploy_path}/releases/*/config | head -1`"
    end
  end
  # after "deploy:finalize_update", "postgresql:symlink"
  after "postgresql:setup", "postgresql:symlink"
end
