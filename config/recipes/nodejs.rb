namespace :nodejs do
  desc "Install the latest relase of Node.js"
  task :install do
    on roles(:app) do
      sudo "add-apt-repository ppa:chris-lea/node.js"
      sudo "apt-get -y update"
      sudo "apt-get -y install nodejs"
    end
  end
  after "deploy:install", "nodejs:install"
end
