set_default(:unicorn_user) { user }
set_default(:unicorn_pid) { "#{current_path}/tmp/pids/unicorn.pid" }
set_default(:unicorn_config) { "#{shared_path}/config/unicorn.rb" }
set_default(:unicorn_log) { "#{shared_path}/log/unicorn.log" }
set_default(:unicorn_workers, 2)

namespace :unicorn do
  desc "Setup Unicorn initializer and app configuration"
  task :setup do # , roles: :app do
    on roles(:app) do
      sudo "mkdir -p #{shared_path}/config"
      template "unicorn.rb.erb", fetch(:unicorn_config)
      template "unicorn_init.erb", "/tmp/unicorn_init"
      sudo "chmod +x /tmp/unicorn_init"
      sudo "mv /tmp/unicorn_init /etc/init.d/unicorn_#{fetch :application}"
      sudo "update-rc.d -f unicorn_#{fetch :application} defaults"
    end
  end
  # after "deploy:setup", "unicorn:setup"
  after "deploy:published", "unicorn:setup"

  %w[start stop restart].each do |command|
    desc "#{command} unicorn"
    task command do # , roles: :app do
      on roles(:app) do
        sudo "service unicorn_#{fetch :application} #{command}"
      end
    end
    after "nginx:#{command}", "unicorn:#{command}"
  end
end
