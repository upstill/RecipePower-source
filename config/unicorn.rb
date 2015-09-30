# working_directory "/var/www/RP/current"
# pid "/var/www/RP/current/tmp/pids/unicorn.pid"
# stderr_path "/var/www/RP/shared/log/unicorn.log"
# stdout_path "/var/www/RP/shared/log/unicorn.log"

# listen "/tmp/unicorn.RP.sock"

worker_processes 1
timeout ((ENV['RAILS_ENV'] == 'development') ? 3000 : 200)
