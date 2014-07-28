class StreamPresenter
  attr_accessor :results

  delegate :items, :next_item, :next_range, :query, :"done?", :window, :to => :results

  def initialize session_id, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    # Format of stream parameter is <start>[:<end>]
    stream_param = params.delete :stream
    @params = params
    if stream_param.blank?
      @offset, @limit = 0, 1000000
    else
      @offset, @limit = stream_param.split('-').map(&:to_i)
      @limit ||= @offset+10
    end

    # Get a Streamer subclass for the controller and action
    @results = ResultsCache.retrieve_or_build session_id, querytags, params
    @results.window = @offset..@limit
=begin
    controller = (params[:controller] || "").capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == "index")
    Object.const_defined?(name = controller+"Streamer") || (name = "Streamer")
    @streamer = name.constantize.new @offset, @limit, params
=end
  end

  def render
    render_to_string partial: "stream_contents"
    # with_format("html") { render_to_string partial: "stream_footer" }
  end

  # Time to emit the stream? 'stream' parameter has item specs
  def stream?
    !@params[:stream].blank?
  end

  # Should the items be dumped now?
  def dump?
    !@params.has_key?(:stream)
  end

  # This is the chance to set what tag types the presenter allows to filter for
  def tagtypes
    nil
  end

end