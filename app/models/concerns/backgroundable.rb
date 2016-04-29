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
  def bkg_enqueue force=false
    # force => do the job even if it was priorly complete
    if virgin? || (force && !(pending? || processing?)) # Don't add it to the queue redundantly
      pending!
      save
      Delayed::Job.enqueue self
    end
    pending?
  end

  # Glean results synchronously, returning only when status is definitive (good or bad)
  # force => do the job even if it was priorly complete
  def bkg_perform force=false
    if virgin? || pending? # Run the scrape process right now
      perform
    elsif processing? # Wait for scraping to return
      until !processing?
        sleep 1
        reload
      end
    elsif force
      pending!
      perform
    end
    good?
  end

  # Finally execute the block that will update the model (or whatever)
  def bkg_execute &block
    if virgin? || pending?
      # Lock during processing
      processing!
      save
      begin
        if block.call
          good!
        else
          bad!
        end
      rescue Exception => e
        bad!
      end
      save
    end
    good?
  end

end