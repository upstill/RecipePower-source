class Streamer
  # The streamer class is defined to respond to a query with a series of items
  # This is a brain-dead integer generator

  attr_accessor :items, :cache

  def next_item
    @item_index = (@item_index ? (@item_index+1) : @offset)
    @item_index if (@item_index < @limit)
  end

  def initialize offset, limit, params
    @offset, @limit = offset, limit
    @item_index = @offset-1
  end

  def items
    @items ||= setup
    @items
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

  def next_item
    @item_index = (@item_index ? (@item_index+1) : @offset)
    @item_index if (@item_index < @limit)
  end

end

class StreamPresenter
  attr_accessor :streamer

  delegate :items, :next_item, :to => :streamer

  def initialize params={}
    # Format of stream parameter is <start>[:<end>]
    @params = params
    if params[:stream]
      @offset, @limit = params[:stream].split(':').map(&:to_i)
      @limit ||= @offset+10
    else
      @offset, @limit = 0, 1000000
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

  def stream_now?
    @params[:stream]
  end

end