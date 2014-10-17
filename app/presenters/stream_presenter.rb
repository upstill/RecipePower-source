class StreamPresenter
  attr_accessor :results, :tagtype, :results_partial, :item_partial, :tail_partial

  delegate :items, :next_item, :next_range, :"done?", :window, :param, :full_size, :to => :results

  def initialize session_id, requestpath, rc_class, userid, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    @thispath = requestpath # stash the path from this request
    # Format of stream parameter is <start>[-<end>]
    @stream_param = params.delete(:stream) || "" if params.has_key? :stream
    @tagtype = params[:tagtype]
    if @stream_param.blank?
      offset = 0
    else
      offset, limit = @stream_param.split('-').map(&:to_i)
    end

    if params[:action] == "index"
      @item_partial = "#{params[:controller]}/index_table_row"
      @results_partial = "#{params[:controller]}/index_stream_results"
      @tail_partial = "stream/table_tail"
    else
      # In general we leave the item partial to the model
      @results_partial = "shared/stream_results_masonry"
      @tail_partial = "stream/masonry_tail"
    end

    # Get a Streamer subclass for the controller and action
    @results = rc_class.retrieve_or_build session_id, userid, querytags, params
    # limit ||= offset + @results.max_window_size
    @results.window = offset, limit
  end

  def render
    render_to_string partial: "stream_contents"
  end

  # Time to emit the stream? 'stream' parameter has item specs
  def stream?
    !@stream_param.blank?
  end

  # Should the items be dumped now?
  def dump?
    false # !instance_variable_defined?(:@stream_param)
  end

  # This is the path that will go into the "more items" link
  def next_path
    if r = @results.next_range
      assert_query @thispath, stream: "#{r.min}-#{r.max}"
    end
  end

  # The query for applying querytags is the same as this one, without :stream or :querytags
  def query format=nil, params={}
    if format.is_a? Hash
      params, format = format, nil
    end
    assert_query @thispath, format, params.merge( stream: nil, querytags: nil )
  end

  # The stream is starting, so perform any prefatory tasks
  def preface?
    @results.window.min == 0
  end

  # Suspend the stream till later
  def suspend
    @results.save if @results
  end

end
