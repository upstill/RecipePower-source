# Clear this for establishing default in .bashrc
if [ -z $HISTSIZE ]; then
	source ~/.bashrc  # Standard Bash startup
fi
source ~/.bashvars  # Get secret credentials

export IPADDR=`curl ifconfig.me`

#### Standard path and script inits:
export PATH="/usr/local/bin:/usr/local/sbin:${HOME}/bin:$PATH"

PATH=$HOME/.rvm/bin:$PATH # Add RVM to PATH for scripting
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

export LC_CTYPE=en_US.UTF-8
if [ -z $RAILS_ENV ]; then
	export RAILS_ENV=production
	echo "RAILS_ENV set to '$RAILS_ENV'. Set it to 'staging' or 'production' for release"
fi
# OS-dependent variables and aliases
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	export HOSTNAME=`cat /etc/hostname`
	# Where the current project is located 
	export APP_HOME=/home/upstill/RecipePower-source
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
		cp /etc/nginx/sites-available/{ngin*,rails*} deploy/sites-available
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
		sudo cp deploy/sites-available/* /etc/nginx/sites-available

		sudo cp deploy/nginx.conf /etc/nginx
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

	export RUBYVER=2.6.6
	export RUBYMAJOR=2.6

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
export APP=example
export RAILS_VER=5.2.3
# gem: --no-document
function install_rails()
{
        sudo gem install rails -v $RAILS_VER
        cd 
        rails new $APP  # Installation will stop at bundle installation. Ctrl-Z out and:
        cd $APP
	bundle install --path vendor/bundle
}

	# Add the bin directory for postgres commands
	export PG_BIN="/usr/lib/postgresql/12/bin"
	export PATH="${PG_BIN}:$PATH"

	# Make rvm commands available
	if [[ -d $HOME/.rbenv ]]; then
		export PATH="$HOME/.rbenv/bin:$PATH"
		eval "$(rbenv init -)"
		export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
	fi

	# PG_HOME is where postgres is installed and the directory where 'locate postgresql.conf' indicates
	# export PG_HOME=/etc/postgresql/12/main # On Staging machine?
	export PG_HOME=/var/lib/postgresql/12/main
	echo "PG_HOME: ${PG_HOME}"

	# Socket-declaration line for config/database.yml
	export PG_SOCKET=/var/run/postgresql/.s.PGSQL.5432
	export PG_LOGS=/var/log/postgresql/postgresql-12-main.log

	# We need APP_HOME to be defined
	export LOG_HOME="${APP_HOME}/log"

	if [[ $PG_HOME =~ /12/ ]]; then
		export PG_LOG=/var/log/postgresql/postgresql-12-main.log
		alias pg_start="sudo -u postgres pg_ctlcluster 12 main start"
		alias pg_stop="sudo -u postgres pg_ctlcluster 12 main stop"
		alias pg_status="sudo -u postgres pg_ctlcluster 12 main status"
	else
		export PG_LOG="${LOG_HOME}/server.log"
		# Postgres control differs on Linux for some reason
		alias pg_start="sudo -u postgres ${PG_BIN}/pg_ctl start -D ${PG_HOME} -l $PG_LOG"
		alias pg_stop="sudo -u postgres ${PG_BIN}/pg_ctl stop -D ${PG_HOME} -s -m fast"
		alias pg_status="sudo -u postgres ${PG_BIN}/pg_ctl status -D ${PG_HOME}"
	fi
	alias pg_log="cat ${PG_LOG}"

	### Added by the Heroku Toolbelt
	export PATH="/snap/bin:$PATH"

elif  [[ "$OSTYPE" == "darwin"* ]]; then
	# .bashvars sets the Postgres password for Linux 
	export POSTGRES_PASSWORD='wRsQ&Pdh#X^rdc/S|9'
	# Where the current project is located 
	export APP_HOME=/Users/upstill/Dev/RP
	# Add the bin directory for postgres commands
	export PATH="/usr/local/opt/postgresql@9.6/bin:$PATH"

	# PG_HOME is where postgres is installed and the directory where 'locate postgresql.conf' indicates
	export PG_HOME="/usr/local/var/postgres"

	# The Postgres socket configuration (not needed on MacOS)
	# export PG_SOCKET=/var/run/postgresql/.s.PGSQL.5432

	# We need APP_HOME to be defined
	export LOG_HOME="${APP_HOME}/log"
	export PG_LOG="${LOG_HOME}/server.log"

	# Postgres control on MacOS
	alias pg_start="pg_ctl -D ${PG_HOME} -l ${LOG_HOME}/server.log start"
	alias pg_stop="pg_ctl -D ${PG_HOME} stop -s -m fast"
	alias pg_status="pg_ctl -D ${PG_HOME} status"

	# If Flutter is installed:
	# FLUTTER_BINS is the bin directory for the Flutter installation
	export PATH="${HOME}/Dev/Flutter/bin:$PATH"

	# ANDROID_BINS is the bin directory for the Android installation
	export PATH="${HOME}/Library/Android/sdk/tools/bin:$PATH"

	# If imagemagick is installed:
	export PATH="/usr/local/Cellar/imagemagick/7.0.8-56/bin:${PATH}"

	# Setting PATH for Python 3.6
	# The original version is saved in .bash_profile.pysave
	# export PYTHON_BINS=
	export PATH="/Library/Frameworks/Python.framework/Versions/3.6/bin:${PATH}"
fi
alias pg_log="cat ${PG_LOG}"

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
        if [ ! -f log/null.log ]; then
                cat /dev/null >log/null.log
        fi
        sudo cp log/null.log log/${RAILS_ENV}.log
        # echo "sudo -u postgres unicorn -c config/unicorn.rb -E $RAILS_ENV -D"
        # sudo /usr/sbin/unicorn -c config/unicorn.rb -E $RAILS_ENV -D
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
	ps -ax | grep unicorn
}

# Link the given nginx config file in /etc/nginx/sites-available to /etc/nginx/sites-enabled
function nu_enable()
{
	echo "Currently enabled: '`ls /etc/nginx/sites-enabled/*`'."
	if [[ -f /etc/nginx/sites-enabled/$1 ]]; then
		echo "Nothing is being changed. As you were."
	elif [[ -f /etc/nginx/sites-available/$1 ]]; then
		echo "$1 is available in /etc/nginx/sites-available"
		sudo rm /etc/nginx/sites-enabled/*
		sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled
		echo "/etc/nginx/sites-enabled now has `ls /etc/nginx/sites-enabled`"
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
	tail /var/log/nginx/access.log
	echo ""
	echo "---------------------"
	echo "/var/log/nginx/error.log:"
	tail /var/log/nginx/error.log
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

function ss()
{
  echo "sudo systemctl $@"
  sudo systemctl $@
}

function clearlog()
{
   cat /dev/null >${APP_HOME}/log/development.log
}

function ack_all()
{
   ack $@ . --ignore-dir=log --ignore-dir=tmp --ignore-dir=doc
}

function vig()
{
   export FLIST=`ack $1 ${2:-"app"} -l` 
   vi +/$1/ $FLIST 
}

export alias HEROKU_STAGING="strong-galaxy-5765-74"
function hks()
{
  echo "heroku $@ --app ${HEROKU_STAGING}"
  heroku $@ --app ${HEROKU_STAGING}
}

export alias HEROKU_PRODUCTION="strong-galaxy-5765"
function hkl()
{
  echo "heroku $@ --app ${HEROKU_PRODUCTION}"
  heroku $@ --app ${HEROKU_PRODUCTION}
}

alias hkl_web="hkl logs --tail | grep 'web.1'"
alias hkl_worker="hkl logs --tail | grep 'worker.1'"

function hkl_mirror()
{
    db_backup production
    db_restore production
}

alias pg_dump_dev="db_backup development"
alias pg_dump_live="db_backup production"
alias pg_dump_staging="db_backup staging"

# Return the full path for a new dump file of the given type
# Call with either 'development', 'staging' or 'production'
export BACKUPS_ROOT=${APP_HOME}/backups
new_dump_file()
{
export BACKUP_DIR_NAME="${BACKUPS_ROOT}/db_backup_$1"
echo "Testing '$BACKUP_DIR_NAME'"
if [ -d $BACKUP_DIR_NAME ]; then
  export DUMP_FILE_NAME="${BACKUP_DIR_NAME}/`date \"+%Y-%m-%d\"`.dump"
  echo "New dump file name: '$DUMP_FILE_NAME'"
else
  echo "new_dump_file: Nope! Need to specify database with current backup, viz: 'db_backup production|staging|development'"
  export DUMP_FILE_NAME=''
fi
}
# Restore the database from the named backup
# Call with either 'development', 'staging' or 'production'
db_backup()
{
new_dump_file $1
if [ -z $DUMP_FILE_NAME ]; then
    echo "db_backup: Nope! Need to specify database with current backup, viz: 'db_backup production|staging|development'"
else
    if [ $1 == 'development' ]; then
	echo "Insert development procedure here..."
	echo "db_backup: pg_dump --verbose -h localhost --clean --format=custom --file="$DUMP_FILE_NAME" dabpmrobtjc0ei"
	pg_dump --verbose -h localhost --clean --format=custom --file="$DUMP_FILE_NAME" dabpmrobtjc0ei
    elif [ $1 == 'staging' ]; then
	hks pg:backups capture DATABASE_URL
        echo "db_backup: curl -o $DUMP_FILE_NAME `heroku pg:backups public-url --app ${HEROKU_STAGING}`"
        curl -o $DUMP_FILE_NAME `heroku pg:backups public-url --app ${HEROKU_STAGING}`
    elif [ $1 == 'production' ]; then
	hkl pg:backups capture DATABASE_URL
        echo "db_backup: curl -o $DUMP_FILE_NAME `heroku pg:backups public-url --app ${HEROKU_PRODUCTION}`"
        curl -o $DUMP_FILE_NAME `heroku pg:backups public-url --app ${HEROKU_PRODUCTION}`
    fi
fi

}

# Restore the database from the named backup
# Call with either 'development', 'staging' or 'production'
db_restore()
{
if [ -d ${BACKUPS_ROOT}/db_backup_$1 ]; then
    export FNAME=`latest_backup_for $1`
    echo "db_restore: Backup file found: '$FNAME'"
    if [ -z $FNAME ]; then
	echo "db_restore: No current backup for '$FNAME'"
    else
        db_restore_from $FNAME $1
    fi
else
    echo "db_restore: Nope! Need to specify database with current backup, viz: 'db_restore production|staging|development'"
fi

}

# Restore the database from the given backup file
db_restore_from()
{
  if [ -z $1 ]; then
	echo "db_restore_from: Need to specify file to restore from: '$1' just won't do!"
  else
	echo "db_restore_from: Restoring from live backup '$1' to '$2'"
	echo "db_restore_from: Doing 'pg_restore --verbose --clean --no-acl --no-owner -h localhost -U upstill -d cookmarks_$2 $1'"
	# pg_restore --verbose --clean --no-acl --no-owner -h localhost -U upstill -d cookmarks_$2 $1
  fi
}
# Locate the latest backup file as date-stamped
# Call with either 'development', 'staging' or 'production'
latest_backup_for()
{
	ls -d -1 ${BACKUPS_ROOT}/db_backup_$1/20*.dump | tail -1
}
