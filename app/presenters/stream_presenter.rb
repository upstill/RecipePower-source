class StreamPresenter
  attr_accessor :results, :tagtype

  delegate :items, :next_item, :next_range, :"done?", :window, :param, :to => :results

  def initialize session_id, requestpath, rc_class, userid, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    @thispath = requestpath # stash the path from this request
    # Format of stream parameter is <start>[-<end>]
    @stream_param = params.delete(:stream) || "" if params.has_key? :stream
    @tagtype = params[:tagtype]
    if @stream_param.blank?
      offset, limit = 0, -1
    else
      offset, limit = @stream_param.split('-').map(&:to_i)
      limit ||= -1
    end

    # Get a Streamer subclass for the controller and action
    @results = rc_class.retrieve_or_build session_id, userid, querytags, params
    limit = offset + @results.window_size if limit < 0
    @results.window = offset..limit
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

end
