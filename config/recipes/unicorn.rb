set :unicorn_user, fetch(:user)
set :unicorn_pids_dir, "#{current_path}/tmp/pids"
set :unicorn_pid, "#{fetch :unicorn_pids_dir}/unicorn.pid"
set :unicorn_config, "#{shared_path}/config/unicorn.rb"
set :unicorn_log, "#{shared_path}/log/unicorn.log"
set :unicorn_workers, (fetch(:stage)==:production ? 2 : 1)

namespace :unicorn do
  desc "Setup Unicorn initializer and app configuration"
  task :setup do # , roles: :app do
    on roles(:app) do
      sudo "mkdir -p #{shared_path}/config"
      execute "mkdir -p #{fetch :unicorn_pids_dir}"
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
