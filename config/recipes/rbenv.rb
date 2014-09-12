set_default :ruby_version, "1.9.3-p125"
set_default :rbenv_bootstrap, "bootstrap-ubuntu-10-04"

namespace :rbenv do
  desc "Install rbenv, Ruby, and the Bundler gem"
  task :install do # , roles: :app do
    on roles(:app) do
      sudo "apt-get -y install curl git-core"
      execute "curl -L https://raw.github.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash"
      bashrc = <<-BASHRC
if [ -d $HOME/.rbenv ]; then 
  export PATH="$HOME/.rbenv/bin:$PATH" 
  eval "$(rbenv init -)" 
fi
BASHRC
      put bashrc, "/tmp/rbenvrc"
      execute "cat /tmp/rbenvrc ~/.bashrc > ~/.bashrc.tmp"
      execute "mv ~/.bashrc.tmp ~/.bashrc"
      execute %q{export PATH="$HOME/.rbenv/bin:$PATH"}
      execute %q{eval "$(rbenv init -)"}
      execute "rbenv #{rbenv_bootstrap}"
      execute "rbenv install #{ruby_version}"
      execute "rbenv global #{ruby_version}"
      execute "gem install bundler --no-ri --no-rdoc"
      execute "rbenv rehash"
    end
  end
  after "deploy:install", "rbenv:install"
end
