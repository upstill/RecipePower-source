namespace :nginx do
  desc "Install latest stable release of nginx"
  task :install do
    on roles(:web) do
      sudo "add-apt-repository --yes ppa:nginx/stable"
      sudo "apt-get -y update"
      sudo "apt-get -y install nginx"
    end
  end
  after "deploy:install", "nginx:install"

  desc "Setup nginx configuration for this application"
  task :setup do
    on roles(:web) do
      template "nginx_unicorn.erb", "/tmp/nginx_conf"
      sudo "mv /tmp/nginx_conf /etc/nginx/sites-enabled/#{fetch :application}"
      sudo "rm -f /etc/nginx/sites-enabled/default"
      sudo "service nginx restart"
    end
  end
  # after "deploy:setup", "nginx:setup"
  after "deploy:published", "nginx:setup"

  %w[start stop restart].each do |command|
    desc "#{command} nginx"
    task command do
      on roles(:web) do
        sudo "service nginx #{command}"
      end
    end
  end
end
