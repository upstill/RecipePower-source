# Clear this for establishing default in .bashrc
if [ -z $HISTSIZE ]; then
	source ~/.bashrc  # Standard Bash startup
fi
source ~/.bashvars  # Get secret credentials

export IPADDR=`curl ifconfig.me`
export DOMAIN=recipepower.com

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
	export RUBYVER=2.6.6
	export RUBYMAJOR=2.6

	export APP=example
	export RAILS_VER=5.2.6

	# Add the bin directory for postgres commands
	export PG_BIN="/usr/lib/postgresql/12/bin"
	export PATH="${PG_BIN}:$PATH"

	# Make rbenv commands available
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

	if [[ $PG_HOME =~ /12/ ]]; then
		export PG_LOG=/var/log/postgresql/postgresql-12-main.log
		alias pg_start="sudo -u postgres pg_ctlcluster 12 main start"
		alias pg_stop="sudo -u postgres pg_ctlcluster 12 main stop"
		alias pg_status="sudo -u postgres pg_ctlcluster 12 main status"
	else

	# We need APP_HOME to be defined
	export LOG_HOME="${APP_HOME}/log"
		export PG_LOG="${LOG_HOME}/server.log"
		# Postgres control differs on Linux for some reason
		alias pg_start="sudo -u postgres ${PG_BIN}/pg_ctl start -D ${PG_HOME} -l $PG_LOG"
		alias pg_stop="sudo -u postgres ${PG_BIN}/pg_ctl stop -D ${PG_HOME} -s -m fast"
		alias pg_status="sudo -u postgres ${PG_BIN}/pg_ctl status -D ${PG_HOME}"
	fi
	alias pg_log="cat ${PG_LOG}"

	### Added by the Heroku Toolbelt
	export PATH="/snap/bin:$PATH"
	
	# Get Linux-only shell commands
	if [[ $- == *i* ]]; then
		echo 'Getting Interactive commands' 
		source ~/.bash_ubuntu
	fi

elif  [[ "$OSTYPE" == "darwin"* ]]; then
	# .bashvars sets the Postgres password for Linux 
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
/var/log/postgresql/postgresql-12-main.log

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
elif [ -d $BACKUPS_ROOT ]; then
  echo "new_dump_file: Nope! Need to specify database with current backup, viz: 'db_backup production|staging|development'"
  export DUMP_FILE_NAME=''
else
  echo "No '$BACKUPS_ROOT' directory!"
fi
}
# Restore the database from the named backup
# Call with either 'development', 'staging' or 'production'
db_backup()
{
new_dump_file $1
if [ ! -z $DUMP_FILE_NAME ]; then
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
	echo "db_restore_from: Doing 'pg_restore --verbose --clean --no-acl --no-owner -h localhost -U postgres -d cookmarks_$2 $1'"
	pg_restore --verbose --clean --no-acl --no-owner -h localhost -U postgres -d cookmarks_$2 $1
  fi
}

# Locate the latest backup file as date-stamped
# Call with either 'development', 'staging' or 'production'
latest_backup_for()
{
	ls -d -1 ${BACKUPS_ROOT}/db_backup_$1/20*.dump | tail -1
}
