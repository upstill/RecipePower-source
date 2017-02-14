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
      # Since enums are defined at the Module level, we need to detect when an enum has been
      # defined in multiple classes. detect_enum_conflict! throws an error, so we assume
      # that the enum has been priorly defined.
      begin
        detect_enum_conflict!(status_attribute, status_attribute.to_s.pluralize, true)
      rescue
        return
      end
      enum status_attribute => [
               :virgin, # Hasn't been executed or queued
               :obs_pending, # Queued but not executed (Obsolete with dj attribute)
               :processing, # Set during execution
               :good, # Executed successfully
               :bad # Executed unsuccessfully
           ]
    end

  end

  included do
    belongs_to :dj,
               :class_name => 'Delayed::Backend::ActiveRecord::Job',
               :dependent => :destroy
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def pending?
    dj.present? && !processing?
  end

  # Fire off worker process to glean results, if needed
  def bkg_enqueue force=false, djopts = {}
    if force.is_a?(Hash)
      force, djopts = false, force
    end
    return true if processing?
    if dj && djopts.present? # Only happens if job already queued, i.e. not virgin, good or bad
      dj.destroy
      self.dj = nil
    end
    if djopts.present? || virgin? || (force && (good? || bad?)) # If never been run, or forcing to run again, enqueue normally
      unless dj
        save if new_record? # Just in case...
        self.dj = Delayed::Job.enqueue self, djopts
        save
      end
    end
    pending?
  end

=begin
  # Place the object's job back in the queue, even if it was previously complete.
  # 'force' will do so even if the job was already queued (good for recovering from crashes)
  def bkg_requeue force=false
    if force || !(self.dj || processing?)
      virgin!
      bkg_enqueue
    end
  end
=end

  # Does this object have a DelayedJob waiting?
  def queued?
    self.dj.present?
  end

  # Glean results synchronously, returning only when status is definitive (good or bad)
  # force => do the job even if it was priorly complete
  def bkg_sync force=false
    if processing? # Wait for worker to return
      until !processing?
        sleep 1
        reload
      end
    elsif force || (self.dj && self.dj.run_at <= Time.now) # Run the process right now
      self.dj ?
          Delayed::Worker.new.run(self.dj) : # Job pending => run it now
          bkg_perform # Run it directly w/o invoking DelayedJob
    end
    good?
  end

  # Just hang out until the process completes
  # NB: MUST HAVE A WORKER PROCESS DOING JOBS!
  # ALSO, CAN TAKE A VERY LONG TIME
  def bkg_wait
    until !queued?
      sleep 1
      reload
    end
  end

  # Wrapper for the #perform method, managing job correctly outside of DelayedJob
  def bkg_perform
    processing!
    perform
  end

  # Finally execute the block that will update the model (or whatever). This is intended to
  # be called within the #perform method, with a block that does the real work and returns
  # either true (for successful execution) or false (for failure). The instance will get status
  # of 'good' or 'bad' thereby
  # We check for the processing flag b/c the job may have been run before (ie., by bkg_sync)
  def bkg_execute &block
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
    good?
  end

  # With success, the DelayedJob record is about to go away, so we remove our pointer
  def success(job)
    self.dj = nil
    save
  end

  def error(job, exception)
    bad!
    errors.add :url, exception.to_s
  end

  # Before the job is performed, revise its status from pending to processing
  def before job
    processing!
  end

end
