namespace :bundler do
  desc "Install prerequisites for bundler"
  task :preinstall do
    on roles(:web) do
      sudo "apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties"
    end
  end
  after "deploy:updated", "bundler:preinstall"
end
