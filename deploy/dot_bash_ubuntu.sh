# BASH functions that only pertain to Ubuntu installation
function extract_rubyver()
{
        if [ ! -f .ruby-version ]; then
                cat Gemfile.lock | grep ^\\s*ruby\\W | sed 's/\s*ruby\s*//' | sed 's/p.*$//' > .ruby-version
        fi
	cat .ruby-version
}

# Copy the current state of scripts and system files into the deploy directory
function git_pack()
{
	if [ -d deploy ]; then
		cp /etc/init.d/unicorn deploy
		cp ~/.bash_profile deploy/dot_bash_profile.sh
		cp ~/.bash_ubuntu deploy/dot_bash_ubuntu.sh
		cp /etc/nginx/sites-available/{ngin*,rails*,RecipePower} deploy/sites-available
		cp /etc/nginx/nginx.conf deploy
		cp /var/www/recipepower.com/html/* deploy/html
	else
		echo "Need to be in a Rails directory to git_pack!"
	fi
}

# After cloning the distribution, copy out various config files that have to live somewhere else
function git_unpack()
{
	if [ -d deploy ]; then
		sudo cp deploy/unicorn /etc/init.d/unicorn
		sudo chmod +x /etc/init.d/unicorn
		sudo update-rc.d unicorn defaults

		cp deploy/dot_bash_profile.sh ~/.bash_profile
		cp deploy/dot_bash_ubuntu.sh ~/.bash_ubuntu
		sudo cp deploy/sites-available/* /etc/nginx/sites-available

		sudo cp deploy/nginx.conf /etc/nginx

		if [ ! -d  /var/www/recipepower.com/html ]; then
			sudo mkdir -p /var/www/recipepower.com/html
			sudo chown upstill /var/www/recipepower.com/html
		fi
		cp deploy/html/* /var/www/recipepower.com/html

		echo "Environment is deployed. Exit and log back in for .bash_profile."
		echo "Restart unicorn and nginx for changes to take effect"
	else
		echo "Need to be in a Rails directory to git_pack!"
	fi
}

function git_clone()
{
	echo "git_clone $1"
	if [ ! -z $1 ]; then
		echo "Setting \$GIT_BRANCH to $1"
		export GIT_BRANCH="$1"
	fi
	if [ -z $GIT_BRANCH ]; then
		echo "git_clone needs to know what branch to clone."
		echo "Either set \$GIT_BRANCH to 'staging' or 'master', or invoke 'git_clone <branchname>'"
	elif [[ $GIT_BRANCH =~ 'staging' || $GIT_BRANCH =~ 'master' ]]; then
		echo "git_clone cloning $GIT_BRANCH."
		git clone -b $GIT_BRANCH --single-branch git@github.com:upstill/RecipePower-source.git
		echo "Done! Don't forget to run git_unpack to distribute configuration, etc., files."
	else
		echo "git_clone: must clone EITHER 'staging' or 'master'"
	fi
}

function git_pull()
{
	echo "git_pull $1"
	if [ ! -z $1 ]; then
		echo "Setting \$GIT_BRANCH to $1"
		export GIT_BRANCH="$1"
	fi
	if [ -z $GIT_BRANCH ]; then
		echo "git_pull needs to know what branch to clone."
		echo "Either set \$GIT_BRANCH to 'staging' or 'master', or invoke 'git_pull <branchname>'"
	elif [[ $GIT_BRANCH =~ 'staging' || $GIT_BRANCH =~ 'master' ]]; then
		echo "git_pull pulling $GIT_BRANCH."
		git pull git@github.com:upstill/RecipePower-source.git
		echo "Done! Don't forget to run git_unpack to distribute configuration, etc., files."
	else
		echo "git_pull: must clone EITHER 'staging' or 'master'"
	fi
}

# Run this from home directory on Linux host
function install_ruby()
{
	pushd ~
        sudo apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev nodejs
        # (Check for ruby version $RUBYVER--e.g., 2.6.3--in the Gemfile with $RUBYMAJOR the major release--e.g., 2.6:)
        wget https://cache.ruby-lang.org/pub/ruby/$RUBYMAJOR/ruby-$RUBYVER.tar.gz
        tar -xzvf ruby-$RUBYVER.tar.gz
        cd ruby-$RUBYVER
        ./configure
        make
        sudo make install
}

####### Functions for controlling the server setup
# NB Everything is under systemctl on Nginx, so once things are working,
# there should be no need to run any of these

function nuhelp()
{
	echo "Manage and control nginx and unicorn FROM RAILS APP DIRECTORY with:"
	echo "'nustart' to start both processes, emptying the log files."
	echo "'nustop' to stop both processes."
	echo "'nurestart' to stop and start."
	echo "'nu_enable <sitefile>' to switch to another file in /etc/nginx/sites-available"
	echo "'nustatus' to get process status."
	echo "'nuconfig' to edit config files."
	echo "'nulogs' to view current log files."
	echo "'nu_errscan' to briefly review current logs."
}

function nustop()
{
    sudo systemctl stop nginx
    sudo systemctl stop unicorn
    sudo pkill unicorn
    sudo rm /home/upstill/RecipePower-source/shared/pids/unicorn.pid
    sudo rm /var/sockets/unicorn.sock
    echo "To edit config files, do 'nuconfig'"
}

function nustart()
{
    # cd /home/upstill/RecipePower-source
    if [[ -f Gemfile ]];  then
        # sudo rm /var/log/nginx/access.log /var/log/nginx/error.log shared/log/unicorn.*.log log/${RAILS_ENV}.log
        sudo rm shared/log/unicorn.*.log log/${RAILS_ENV}.log
        echo "sudo systemctl start unicorn"
	sudo sudo systemctl start unicorn
        echo "sudo systemctl start nginx"
        sudo sudo systemctl start nginx
        echo "To check logs, do 'nulogs'"
    else
        echo "No Gemfile => Not running from a Rails directory. 'cd' to one and try again."
    fi
}

alias nurestart="nustop && nustart"

function nustatus()
{ 
	systemctl status nginx 
	systemctl status unicorn 
	ps -ax | grep unicorn
}

# Link the given nginx config file in /etc/nginx/sites-available to /etc/nginx/sites-enabled
function nu_enable()
{
	echo "Currently enabled: '`ls /etc/nginx/sites-enabled/*`'."
	if [[ -f /etc/nginx/sites-enabled/$1 ]]; then
		sudo echo "$1 is already enabled, but run 'nurestart' if the config file has changed."
		sudo nginx -t
	elif [[ -f /etc/nginx/sites-available/$1 ]]; then
		echo "$1 is available in /etc/nginx/sites-available"
		sudo rm /etc/nginx/sites-enabled/*
		sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled
		echo "/etc/nginx/sites-enabled now has `ls /etc/nginx/sites-enabled`"
		sudo nginx -t
		echo "Run 'nurestart' for changes to take effect."
	elif [ -z $1 ]; then
		echo "USAGE: 'nu_enable <file>' where <file> is one of:"
		ls /etc/nginx/sites-available
	else
		echo "$1 is NOT available in /etc/nginx/sites-available. Choices are:"
		ls /etc/nginx/sites-available
	fi
}

alias nuconfig="sudo vi /etc/nginx/nginx.conf /etc/nginx/sites-enabled/* config/unicorn.rb"

function nulogs()
{
    sudo vi /var/log/nginx/access.log /var/log/nginx/error.log  shared/log/unicorn.stderr.log shared/log/unicorn.stdout.log log/${RAILS_ENV}.log $PG_LOG
}

function nu_errscan()
{
	echo "---------------------"
	echo "journalctl -xe | tail:"
	journalctl -xe | tail
	echo "---------------------"
	echo "systemctl status unicorn.service:"
	systemctl status unicorn.service
	echo ""
	echo "---------------------"
	echo "/var/log/nginx/access.log:"
	sudo tail /var/log/nginx/access.log
	echo ""
	echo "---------------------"
	echo "/var/log/nginx/error.log:"
	sudo tail /var/log/nginx/error.log
	echo ""
	echo "---------------------"
	echo "shared/log/unicorn.stderr.log:"
	tail shared/log/unicorn.stderr.log
	echo ""
	echo "---------------------"
	echo "shared/log/unicorn.stdout.log:"
	tail shared/log/unicorn.stdout.log
	echo ""
	echo "---------------------"
	echo "$PG_LOG:"
	sudo tail $PG_LOG
	echo ""
	echo "---------------------"
}

function ss()
{
  echo "sudo systemctl $@"
  sudo systemctl $@
}
