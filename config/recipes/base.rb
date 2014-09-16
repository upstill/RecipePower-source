def template(from, to)
  erb = File.read(File.expand_path("../templates/#{from}", __FILE__))
  erbstr = ERB.new(erb).result(binding)
  upload! StringIO.new(erbstr), to
end

def set_default(name, *args, &block)
  set(name, *args, &block) unless defined?(name) # exists?(name)
end

namespace :deploy do
  desc "Install everything onto the server"
  task :install do
    sudo "apt-get -y update"
    sudo "apt-get -y install python-software-properties"
  end

  desc "Ensure the deploy directory is setup"
  task :ensure_www do
    if test "[ ! -d #{deploy_to} ]"
      on roles(:app) do |host|
        sudo "mkdir -p #{deploy_to}"
        sudo "chown #{user}:#{user} #{deploy_to}"
        execute "umask 0002"
        execute "chmod g+s #{deploy_to}"
        execute "mkdir #{deploy_to}/{releases,shared}"
        execute "chown #{user} #{deploy_to}/{releases,shared}"
      end
    end
  end
end
