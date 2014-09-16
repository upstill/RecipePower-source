namespace :bundler do
  desc "Install prerequisites for bundler"
  task :preinstall do
    on roles(:web) do
      sudo "apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties"
    end
  end
  before "bundler:install", "bundler:preinstall"
end
