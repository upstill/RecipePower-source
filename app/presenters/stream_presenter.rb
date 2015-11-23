class StreamPresenter
  attr_accessor :tagtype
  attr_reader :this_path, :results_cache

  delegate :items, :next_item, :next_range, :admin_view, :stream_id,
           :"done?", :window, :param, :result_type,
           :full_size, :"has_query?", :"ready?",
           :querytags, :nmatches, :org,
           :to => :results_cache

  def initialize session_id, requestpath, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    @this_path = assert_query requestpath # , nocache: nil, id: nil # stash the path from this request
    # Format of stream parameter is <start>[-<end>]
    @stream_param = params.delete(:stream) || "" if params.has_key? :stream
    @tagtype = params[:tagtype]
    if @stream_param.blank?
      offset = 0
    else
      offset, limit = @stream_param.split('-').map(&:to_i)
    end

    # Get a Streamer subclass for the controller and action
    @results_cache = ResultsCache.retrieve_or_build session_id, querytags, params
    # limit ||= offset + results_cache.max_window_size
    results_cache.window = offset, limit
  end

  # This is the path that will go into the "more items" link
  def next_path
    if r = results_cache.next_range
      assert_query @this_path, stream: "#{r.min}-#{r.max}"
    end
  end

  # The query for applying querytags is the same as this one, without :stream, :querytags or :nocache
  def query format=nil, params={}
    if format.is_a? Hash
      params, format = format, nil
    end
    assert_query @this_path, format, params.merge( stream: nil, querytags: nil )
  end

  # Suspend the stream till later
  def suspend
    results_cache.save if results_cache
  end

end
