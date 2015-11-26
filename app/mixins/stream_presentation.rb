module StreamPresentation
  extend ActiveSupport::Concern

  included do
    attr_reader :results_cache

    delegate :items, :next_item, :next_range, :stream_id,
             :"done?", :"ready?", :window, :full_size, :nmatches,
             :to => :results_cache
  end

  def init_stream rc
    if @results_cache = rc
      if @stream.blank?
        offset = 0
      else
        offset, limit = @stream.split('-').map(&:to_i)
      end
      rc.window = offset, limit
    end
  end

  def params_needed
    (defined?(super) ? super : []) + [ [:stream, ''] ]
  end

  # Get the stream param(s) for the next range
  def stream_params_next
    if r = next_range
      { stream: "#{r.min}-#{r.max}" }
    end
  end

  # Get the stream params for resetting the stream
  def stream_params_null
    { stream: nil }
  end

  # Suspend the stream till later
  def suspend
    results_cache.save
  end

end
