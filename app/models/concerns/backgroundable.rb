# The Backgroundable module supplies an object with the ability to manage execution using DelayedJob
#
# Execution may be either synchronous or asynchronous, and a queued job may be recalled from the
# queue and executed synchronously.
#
# Backgroundable jobs are also tidy: a job will only be queued once, and once executed, it will not
# be queued again until reset to virgin state. (This behavior can be overridden by the management methods)
#
# A Backgroundable record keeps a status variable, an enum with three states:
# 1. :virgin => this record has never been processed
# 2. :good => this record has been processed with a good outcome
# 3. :bad => this record has been processed with a bad outcome. Whether it gets reprocessed is up to the application.
#
# There are four primary public methods: bkg_enqueue gets a job running; bkg_sync ensures that the job has run if it's
# due (in-process as necessary); bkg_go runs the job NOW, even if it's not due and (optionally) even if it's run before;
# bkg_asynch() hangs until the worker process has completed, if any.
#
# Canonically, <b>bkg_enqueue() starts the job, bkg_sync() picks it up later, bkg_go() forces it to run, and bkg_asynch()
# waits for the worker to finish with it. Only bkg_asynch() requires that it be previously enqueued.</b>
#
#   bkg_enqueue(refresh, djopts={}) fires off a DelayedJob job.
#
# +refresh+ is a Boolean flag indicating that
# the job should be rerun if was already run.
#
# +djopts+ are options (run_time, etc.,) passed to Delayed::Job
#
#   bkg_sync(run_early=false) checks on the status of a job, returning only when it's complete (if it isn't early).
#
# If the job is due (+run_at+ <= +Time.now+), it forces the
# job to run (+run_early+ being a flag that forces it to run anyway), and if the job is not queued, it
# forces it to run synchronously.
#
# In all cases except a future job (when +run_early+ is not set) bkg_sync() doesn't return
# until the job is complete.
#
#   bkg_go() => Boolean runs the job synchronously (unless previously complete)
#   bkg_go(true) => Boolean runs the job synchronously regardless of whether it was previously complete
#
# In both cases, the DelayedJob is run appropriately if the job has been queued.
#
#   bkg_asynch() sleeps until the worker process has completed the job asynchronously
#
# The only other modification required to run Backgroundable is in the +perform+ record method.
#
# Instead of straightforwardly running the requisite code, +perform+ should enclose that code in a block
# passed to bkg_execute(). That code should return true or false, indicating success or failure (which will set
# the record's status to :good or :bad)
#
# The status of a job may be queried using:
# 1. queued?() indicates that a DelayedJob job is attached
# 2. pending?() indicates that it's queued but not processing
# 3. processing?() is true while the job is actually executing
#
# NB: the #success, #error and #before DelayedJob hooks are defined. Thus, any Backgroundable entity should
# invoke super from any of those hooks that it defines.
#
# :title:Backgroundable
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
      if method_defined? :"#{status_attribute}="
        x=2
      else
        enum status_attribute => [
                 :virgin, # Hasn't been executed or queued
                 :obs_pending, # Queued but not executed (Obsolete with dj attribute)
                 :processing, # Set during execution
                 :good, # Executed successfully
                 :bad # Executed unsuccessfully
             ]
      end
      # Clear the status attribute of all entities that may have been interrupted
      # NB: The test pertains when migrating the status and dj_id columns, which don't yet exist
      if ActiveRecord::Base.connection.column_exists?(self.model_name.collection, status_attribute) # Need to check b/c we may be going into the migration that provides status
        self.where(status: 2, dj_id: nil).update_all status_attribute.to_sym => 0 # Mark all executing objects as virgin to prevent processing deadlock
      end
    end

  end

  included do
    belongs_to :dj,
               :class_name => 'Delayed::Backend::ActiveRecord::Job',
               :dependent => :destroy

    # These overrides provide for setting status before a backgroundable has been saved
    def virgin!
      if persisted?
        super
      else
        self.status = 0
      end
    end

    def processing!
      if persisted?
        super
      else
        self.status = 2
      end
    end

    def good!
      if persisted?
        super
      else
        self.status = 3
      end
    end

    def bad!
      if persisted?
        super
      else
        self.status = 4
      end
    end
  end

  # STI subclasses need to appear to DelayedJob as their base class for retrieval
  def as_base
    self.becomes self.class.base_class
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Does this object have a DelayedJob waiting?
  def queued?
    dj.present?
  end

  # Awaiting execution
  def pending?
    queued? && !processing?
  end

  # bkg_enqueue(refresh, djopts={}) fires off a DelayedJob job. 'refresh' is a Boolean flag indicating that
  # the job should be rerun if was already run. 'djopts' are options (run_time, etc.,) passed to Delayed::Job
  def bkg_enqueue refresh=false, djopts = {}
    if refresh.is_a?(Hash)
      refresh, djopts = false, refresh
    end
    return true if processing?
    if dj # Job is already queued
      if refresh && djopts.present? && dj.locked_by.blank? # If necessary and possible, modify parameters
        dj.with_lock do
          dj.update_attributes djopts
          dj.save if dj.changed?
        end
      end
      return pending?
    elsif virgin? || refresh # If never been run, or forcing to run again, enqueue normally
      save if new_record? # Just in case (so DJ gets a retrievable record)
      self.dj = Delayed::Job.enqueue as_base, djopts
      save
    end
    pending?
  end

  # Glean results synchronously, returning only when status is definitive (good or bad)
  # run_early => do the job even if it's not due
  # bkg_sync(run_early=false) checks on the status of a job. If the job is due (run_at <= Time.now), it forces the
  # job to run ('run_early' being a flag that forces it to run anyway), and if the job is not queued, it
  # forces it to run synchronously. In all cases except a future job (when run_early is not set) bkg_sync doesn't return
  # until the job is complete.
  def bkg_sync run_early=false
    if processing? # Wait for worker to return
      until !processing?
        sleep 1
        reload
      end
    elsif dj # Job pending => run it now, as necessary
      # Force execution if it's never been completed, or it's due, or we force the issue
      if virgin? || (dj.run_at <= Time.now) || run_early
        Delayed::Worker.new.run(dj)
        reload
      end
    elsif virgin?
      processing!
      perform
    end
    good?
  end

  # Cancel the job nicely, i.e. if it's running wait till it completes
  def bkg_kill with_extreme_prejudice=false
    while processing? && !with_extreme_prejudice
      sleep 1
      reload
    end
    dj.destroy
    update_attribute :dj_id, nil
  end

  # bkg_go(refresh=false) runs the job synchronously, using DelayedJob appropriately if the job is queued.
  #
  # 'refresh' flag overrides the status attribute so that the job runs even if previously complete.
  def bkg_go refresh=false
    if processing? || dj # Wait for worker to return
      bkg_sync true
    elsif virgin? || refresh
      processing!
      perform
    end
    good?
  end

  # bkg_asynch() waits for the worker process to complete the job
  #
  # NB: MUST HAVE A WORKER PROCESS DOING JOBS!
  # ALSO, CAN TAKE A VERY LONG TIME
  # Only call this if you REALLY want the job to be performed in the worker, and you're
  # willing to wait for it.
  #
  def bkg_asynch
    until !queued?
      sleep 1
      reload
    end
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
