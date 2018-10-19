# Documentation at https://github.com/collectiveidea/delayed_job
Delayed::Worker.sleep_delay = 1
# Delayed::Worker.destroy_failed_jobs = false
# Delayed::Worker.sleep_delay = 60
Delayed::Worker.max_attempts = 3
# Delayed::Worker.max_run_time = 5.minutes
# Delayed::Worker.read_ahead = 10
# Delayed::Worker.default_queue_name = 'default'
# Delayed::Worker.delay_jobs = !Rails.env.test?
# Delayed::Worker.raise_signal_exceptions = :term
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))
require_relative '../../app/models/scraper.rb'