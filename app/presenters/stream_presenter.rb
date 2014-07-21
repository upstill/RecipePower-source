class Streamer
  # The streamer class is defined to respond to a query with a series of items
  # This is a brain-dead integer generator

  attr_accessor :items, :cache

  def next_item
    result = @next_item_index if (@next_item_index < @limit)
    @next_item_index = @next_item_index + 1
    result
  end

  def next_path
    newlimit = @next_item_index+(@limit-@offset)
    "/integers?stream=#{@next_item_index}-#{newlimit}"
  end

  def initialize offset, limit, params
    limit = (offset+10) if limit > (offset+10)
    @offset, @limit = offset, limit
    @next_item_index = @offset
  end

  def items
    @items ||= setup
    @items
  end

  def done?
    @item_index >= @limit
  end

protected

  def setup
    (@offset...@limit).to_a
  end

end

class IntegerStreamer < Streamer

end

class IntegersStreamer < Streamer

  def items
    (@offset...@limit).to_a
  end

end

class StreamPresenter
  attr_accessor :streamer

  delegate :items, :next_item, :next_path, :"done?", :to => :streamer

  def initialize params={}
    # Format of stream parameter is <start>[:<end>]
    @params = params
    if params[:stream].blank?
      @offset, @limit = 0, 1000000
    else
      @offset, @limit = params[:stream].split('-').map(&:to_i)
      @limit ||= @offset+10
    end

    # Get a Streamer subclass for the controller and action
    controller = (params[:controller] || "").capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == "index")
    Object.const_defined?(name = controller+"Streamer") || (name = "Streamer")
    @streamer = name.constantize.new @offset, @limit, params
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

end