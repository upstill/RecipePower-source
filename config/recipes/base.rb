def template(from, to)
  erb = File.read(File.expand_path("../templates/#{from}", __FILE__))
  upload! ERB.new(erb).result(binding), to
end

def set_default(name, *args, &block)
  set(name, *args, &block) unless defined?(name) # exists?(name)
end

namespace :deploy do
  desc "Install everything onto the server"
  task :install do
    execute "#{sudo} apt-get -y update"
    execute "#{sudo} apt-get -y install python-software-properties"
  end
end
