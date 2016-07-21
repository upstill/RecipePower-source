# The Backgroundable module supplies an object with the ability to manage execution using DelayedJob
# It keeps a status variable as below.
# Execution may be either synchronous or asynchronous, and a queued job may be recalled from the
# queue and executed synchronously.
# Backgroundable jobs are also tidy: a job will only be queued once, and once executed, it will not
# be queued again until reset to virgin state.

module Backgroundable
  extend ActiveSupport::Concern

  module ClassMethods

    def backgroundable status_attribute=:status
      attr_accessible status_attribute
      enum status_attribute => [
               :virgin,  # Hasn't been executed or queued
               :pending, # Queued but not executed
               :processing, # Set during execution
               :good, # Executed successfully
               :bad   # Executed unsuccessfully
           ]
    end

  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Fire off worker process to glean results, if needed
  def bkg_enqueue force=false, djopts = {}
    if force.is_a?(Hash)
      force, djopts = false, force
    end
    # force => do the job even if it was priorly complete
    if virgin? || (force && !(pending? || processing?)) # Don't add it to the queue redundantly
      pending!
      save
      Delayed::Job.enqueue self, djopts
    end
    pending?
  end

  # Place the object's job back in the queue, even if it was previously complete.
  # 'force' will do so even if the job was already queued (good for recovering from crashes)
  def bkg_requeue force=false
    if force || !(pending? || processing?)
      virgin!
      bkg_enqueue
    end
  end

  # Glean results synchronously, returning only when status is definitive (good or bad)
  # force => do the job even if it was priorly complete
  def bkg_sync force=false
    if processing? # Wait for worker to return
      until !processing?
        sleep 1
        reload
      end
    elsif virgin? || pending? || force # Run the process right now
      bkg_perform false
    end
    good?
  end

  # Wrapper for the #perform method, managing job correctly
  def bkg_perform with_save=true
    processing!
    save # Necessary, to notify queue handler that the job is in process
    perform with_save
  end

  # Finally execute the block that will update the model (or whatever). This is intended to
  # be called within the #perform method, with a block that does the real work and returns
  # either true (for successful execution) or false (for failure). The instance will get status
  # of 'good' or 'bad' thereby
  # We check for the processing flag b/c the job may have been run before (ie., by bkg_sync)
  def bkg_execute with_save=true, &block
    if processing?
      # In development, let errors fly
      if Rails.env.development? || Rails.env.test?
        if block.call
          good!
        else
          bad!
        end
      else
        begin
          if block.call
            good!
          else
            bad!
          end
        rescue Exception => e
          error nil, e
        end
      end
    end
    save if with_save
    good?
  end

  # Callbacks for DelayedJob: jobs are pending when they are to run ASAP
=begin
  def enqueue(job)
    unless job.run_at && (job.run_at > Time.now)
      pending!
      save
    end
  end
=end

  def error(job, exception)
    bad!
    errors.add :url, exception.to_s
  end

  # Before the job is performed, revise its status from pending to processing
  # NB: if it's not pending, then the job has been executed by other
  # means (perhaps by bkg_sync) and should be ignored
  def before(job)
    if pending?
      processing!
      save
    end
  end

end