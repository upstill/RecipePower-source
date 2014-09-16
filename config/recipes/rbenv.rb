set :ruby_version, "1.9.3-p286"
set :rbenv_bootstrap, "bootstrap-ubuntu-12-04"

namespace :rbenv do

  desc "Install rbenv, Ruby, and the Bundler gem"
  task :install do # , roles: :app do
    on roles(:app) do |host|
=begin
      NB: BEFORE THIS RUNS, THERE MUST BE SSH ACCESS TO THE SERVER!!
      ON SERVER:
        adduser upstill
        # As root, edit /etc/sudoers file and add this line after the 'root' line under User privilege specification:
        upstill ALL=(ALL) NOPASSWD: ALL
        # As upstill:
        chmod 0700 ~/.ssh
        chmod 0600 ~/.ssh/authorized_keys
      THEN Copy ~/.ssh/id_rsa.pub from local machine to ~/.ssh/authorized_keys on server
      LOCALLY: ssh-add -K
=end
      if test "[ ! -d ~/.rbenv ]"
        sudo "apt-get -y update"
        sudo "apt-get -y install curl git-core"
        execute "curl --silent -L https://raw.github.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash"
        bashrc = <<-BASHRC
if [ -d $HOME/.rbenv ]; then 
  export PATH="$HOME/.rbenv/bin:$PATH" 
  eval "$(rbenv init -)" 
fi
        BASHRC
        upload! StringIO.new(bashrc), "/tmp/rbenvrc"
        execute "cat /tmp/rbenvrc ~/.bashrc > ~/.bashrc.tmp"
        execute "mv ~/.bashrc.tmp ~/.bashrc"
        execute %q{export PATH="$HOME/.rbenv/bin:$PATH"}
        execute %q{eval "$(rbenv init -)"}
      end
      execute "rbenv #{fetch :rbenv_bootstrap}"
      if test "[ ! -d ~/.rbenv/versions/#{fetch :ruby_version} ]"
        execute "rbenv install #{fetch :ruby_version}"
        execute "rbenv global #{fetch :ruby_version}"
      end
      execute "gem install bundler --no-ri --no-rdoc"
      execute "rbenv rehash"
    end
  end
  before "deploy:install", "rbenv:install"
end
