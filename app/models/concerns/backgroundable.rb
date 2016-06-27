module Backgroundable
  extend ActiveSupport::Concern

  module ClassMethods

    def backgroundable status_attribute=:status
      attr_accessible status_attribute
      enum status_attribute => [ :virgin, :pending, :processing, :good, :bad ]
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
      # save unless id
      Delayed::Job.enqueue self, djopts
    end
    pending?
  end

  # Glean results synchronously, returning only when status is definitive (good or bad)
  # force => do the job even if it was priorly complete
  def bkg_sync force=false
    if processing? # Wait for worker to return
      until !processing?
        sleep 1
        reload
      end
    elsif virgin? || pending? || force # Run the scrape process right now
      # Lock during processing
      before nil
      perform
    end
    good?
  end

  # Finally execute the block that will update the model (or whatever)
  def bkg_execute &block
    begin
      if block.call
        good!
      else
        bad!
      end
      save
    rescue Exception => e
      error nil, e
    end
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
    save
  end

  def before(job)
    processing!
    save
  end

end