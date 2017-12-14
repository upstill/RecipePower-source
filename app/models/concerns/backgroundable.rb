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
      unless method_defined? :"#{status_attribute}="
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
        self.status = :virgin
      end
    end

    def processing!
      if persisted?
        super
      else
        self.status = :processing
      end
    end

    def good!
      if persisted?
        super
      else
        self.status = :good
      end
    end

    def bad!
      if persisted?
        super
      else
        self.status = :bad
      end
    end
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

  def due?
    (dj && (dj.run_at <= Time.now)) || processing?
  end

  # bkg_launch(refresh, djopts={}) fires off a DelayedJob job as necessary.
  # NB: MUST NOT BE CALLED ON AN ENTITY WITH UNSAVED CHANGES, as it reloads
  # Return: true if the job is actually queued, false otherwise (useful for launching dependent jobs)
  # 'refresh': a Boolean flag indicating that the job should be rerun even if was already run.
  # 'djopts': options (run_time, etc.,) passed to Delayed::Job
  def bkg_launch refresh=false, djopts = {}
    # We need to reload to ensure we're not stepping on existing processing.
    # Therefore, it is an error to be called with a changed record
    if dj
      reload
      return true if processing?
    end
    if refresh.is_a?(Hash)
      refresh, djopts = false, refresh
    end
    if dj # Job is already queued
      djopts[:run_at] ||= Time.now if refresh # Acting as if the job is being queued afresh
      if djopts.present? && dj.locked_by.blank? # If necessary and possible, modify parameters
        dj.with_lock do
          dj.update_attributes djopts
          dj.save if dj.changed?
        end
      end
      puts ">>>>>>>>>>> bkg_launch redundant on #{self} (dj #{self.dj})"
    elsif virgin? || refresh # If never been run, or forcing to run again, enqueue normally
      save if !id # Just in case (so DJ gets a retrievable record)
      self.dj = Delayed::Job.enqueue self, djopts
      update_attribute :dj_id, dj.id
      puts ">>>>>>>>>>> bkg_launched #{self} (dj #{self.dj})"
    end
    pending?
  end

  # Glean results synchronously, returning only when status is definitive (good or bad)
  # run_early => do the job even if it's not due
  # bkg_sync(run_early=false) checks on the status of a job. If the job is due (run_at <= Time.now), it forces the
  # job to run ('run_early' being a flag that forces it to run anyway), and if the job is not queued, it
  # runs it synchronously. In all cases except a future job (when run_early is not set) bkg_sync doesn't return
  # until the job is complete.
  def bkg_land force=false
    reload if persisted? # Sync with external version
    if processing? # Wait for worker to return
      until !processing?
        sleep 1
        reload
      end
    elsif dj # Job pending => run it now, as necessary
      # There's an associated job. If it's due (dj.run_at <= Time.now), or never been run (virgin), run it now.
      # If it HAS run, and it's due in the future, that's either because
      # 1) it failed earlier and is awaiting rerun, or
      # 2) it just needs to be rerun periodically
      # Force execution if it's never been completed, or it's due, or we force the issue
      begin
        if virgin? || (dj.run_at <= Time.now)
          dj.payload_object = self # ...ensuring that the two versions don't get out of sync
          puts ">>>>>>>>>>> bkg_land #{self} with dj #{self.dj}"
          Delayed::Worker.new.run dj
        end
          # status = :good
      rescue Exception => e
        status = :bad
      end
    elsif virgin? || force # No DJ
      puts ">>>>>>>>>>> bkg_land #{self} (no dj)"
      perform_without_dj
    end
    good?
  end

  # Run the job to completion (synchronously) whether it's due or not
  def bkg_land! force=false
    dj.update_attribute(:run_at, Time.now) if dj && (dj.run_at > Time.now)
    bkg_land force
  end

  # Cancel the job nicely, i.e. if it's running wait till it completes
  def bkg_kill
    reload
    while processing?
      sleep 1
      reload
    end
    if dj
      dj.destroy
      save
    end
  end

  # Run the job, mimicking the hook calls of DJ
  def perform_without_dj
    begin
      before
      perform
      success
    rescue Exception => e # rubocop:disable RescueException
      error nil, e
    ensure
      after
    end
    save if persisted? && changed?
  end

  # Before the job is performed, set the object's status to :processing to forestall redundant processing
  def before job=nil
    processing!
  end

  # We get to success without throwing an error, throw one if appropriate so DJ doesn't think we're cool
  def success job=nil
    # ...could have gone error-free just because errors were reported only in the record
    if self.errors.any?
      raise Exception, self.errors.full_messages # Make sure DJ gets the memo
    else # With success and no errors, the DelayedJob record--if any--is about to go away, so we remove our pointer to it
      self.dj = nil
    end
  end

  # When an unhandled error occurs, record it among the object's errors
  # We get here EITHER because:
  # 1) Normal processing threw an error
  # 2) There were errors on the handler that didn't result in an error, and got thrown by #success
  # NB: THIS IS THE PLACE FOR BACKGROUNDABLES TO RECORD ANY PERSISTENT ERROR STATE beyond :good or :bad status,
  # because, by default, that's all that's left after saving the record
  def error job, exception
    errors.add :base, exception.to_s
  end

  # The #after hook is called after #success and #error
  # At this point, the dj record persists iff there was an error (whether thrown by the work itself or by #success)
  def after job=nil
    self.status = self.errors.any? ? :bad : :good
    save # By this point, any error state should be part of the record
  end

end
