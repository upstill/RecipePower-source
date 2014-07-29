class StreamPresenter
  attr_accessor :results

  delegate :items, :next_item, :next_range, :"done?", :window, :to => :results

  def initialize session_id, requestpath, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    @thispath = requestpath # stash the path from this request
    # Format of stream parameter is <start>[-<end>]
    @stream_param = params.delete :stream if params[:stream]
    # @params = params
    if @stream_param.blank?
      @offset, @limit = 0, 1000000
    else
      @offset, @limit = @stream_param.split('-').map(&:to_i)
      @limit ||= @offset+10
    end

    # Get a Streamer subclass for the controller and action
    @results = ResultsCache.retrieve_or_build session_id, querytags, params
    @results.window = @offset..@limit
  end

  def render
    render_to_string partial: "stream_contents"
    # with_format("html") { render_to_string partial: "stream_footer" }
  end

  # Time to emit the stream? 'stream' parameter has item specs
  def stream?
    !@stream_param.blank?
  end

  # Should the items be dumped now?
  def dump?
    !instance_variable_defined?(:@stream_param)
  end

  # This is the chance to set what tag types the presenter allows to filter for
  def tagtypes
    nil
  end

  # This is the path that will go into the "more items" link
  def next_path
    if r = @results.next_range
      assert_query @thispath, stream: "#{r.min}-#{r.max}"
    end
  end

  # The query for applying querytags is the same as this one, without :stream or :querytags
  def query params={}
    assert_query @thispath, params.merge( stream: nil, querytags: nil )
  end

end