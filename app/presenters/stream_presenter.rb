class StreamPresenter
  attr_accessor :results, :tagtype
  attr_reader :this_path

  delegate :items, :next_item, :next_range,
           :"done?", :window, :param,
           :full_size, :"has_query?", :"ready?",
           :querytags, :nmatches,
           :to => :results

  def initialize session_id, requestpath, rc_class, userid, as_admin, querytags=[], params={}
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
    @results = rc_class.retrieve_or_build session_id, userid, as_admin, querytags, params
    # limit ||= offset + @results.max_window_size
    @results.window = offset, limit
  end

  # This is the path that will go into the "more items" link
  def next_path
    if r = @results.next_range
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
    @results.save if @results
  end

  def stream_id
    results.stream_id
  end

end
