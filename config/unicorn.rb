# working_directory "/var/www/RP/current"
# pid "/var/www/RP/current/tmp/pids/unicorn.pid"
# stderr_path "/var/www/RP/shared/log/unicorn.log"
# stdout_path "/var/www/RP/shared/log/unicorn.log"

# worker_processes 1
timeout ((ENV['RAILS_ENV'] == 'development') ? 3000 : 200)

# set path to the application
app_dir = File.expand_path("../..", __FILE__)
shared_dir = "#{app_dir}/shared"
working_directory app_dir

# Set unicorn options
# worker_processes 2
preload_app true
timeout 30

# Path for the Unicorn socket
listen "/var/sockets/unicorn.sock", :backlog => 64

# Set path for logging
stderr_path "#{shared_dir}/log/unicorn.stderr.log"
stdout_path "#{shared_dir}/log/unicorn.stdout.log"

# Set proccess id path
pid "#{shared_dir}/pids/unicorn.pid"

