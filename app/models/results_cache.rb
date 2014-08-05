class ResultsCache < ActiveRecord::Base
  # The ResultsCache class responds to a query with a series of items.
  # As a model, it saves intermediate results to the database
  self.primary_key = "session_id"

  # scope :integers_cache, -> { where type: 'IntegersCache' }
  attr_accessible :session_id, :params, :cache, :cur_position, :limit
  serialize :params
  serialize :cache
  attr_accessor :items, :querytags, :window

  # Get the current results cache and return it if relevant. Otherwise,
  # create a new one
  def self.retrieve_or_build session_id, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    ((rc = self.find_by session_id: session_id) && (rc.class == self) && (rc.params == params)) ?
        rc :
        self.new( session_id: session_id, querytags: querytags, params: params)
  end

  # Derive the class of the appropriate cache handler from the controller, action and other parameters
  def self.type params
    controller = (params[:controller] || "").singularize.capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == "index")
    controller = controller + params[:owned].to_s.capitalize if params[:action] && (params[:action] == "showowned")
    Object.const_defined?(name = controller+"Cache") || (name = "ResultsCache")
    name.constantize
  end
  
  def initialize params
    super # Let ActiveRecord take care of initializing attributes
    self.limit = full_size # Figure the maximum extent of the results
  end

  # Provide the stream parameter for the "next page" link. Will be null if we've passed the window
  def next_range
    newmax = cur_position+(window.max-window.min)
    if limit < 0 # All indexes are valid
      cur_position..newmax
    elsif cur_position < limit
      newmax = limit if newmax > limit
      cur_position..newmax
    end
  end

  def window= r
    if limit >= 0
      upper = (r.max < limit) ? r.max : limit
      lower = (r.min < limit) ? r.min : (limit-1)
      @window = lower..upper
    else
      @window = r
    end
    self.cur_position = r.min
    @items = nil
  end

  def done?
    @item_index >= window.max
  end

  # This is the real interface, which returns items for display
  # Return the collection of items in the current window
  def items
    raise 'Abstract Method'
  end

  # Return the query that will be augmented with querytags to filter this stream
  def query
    raise 'Abstract Method'
  end

  # Return the total number of items in the result. This doesn't have to be every possible item, just
  # enough to stay ahead of the window.
  def full_size
    -1 # Default is infinite scrolling
  end

  # Return the next item, incrementing the cur_position
  def next_item
    if (i = next_index) && items # i is relative to the current window
      items[i]
    end
  end

  # Here's where we suggest the typical size of window
  def window_size
    10
  end

  protected

  # Get the index of the next element, subject to the constraints of the current window,
  # optionally incrementing the current position
  def next_index hold=false
    if cur_position < window.max
      this_position = cur_position
      self.cur_position = cur_position + 1 unless hold
      this_position - window.min # Relativize the index
    end
  end

end

class IntegersCache < ResultsCache
  # This is a brain-dead integer generator
  def items
    @items ||= (window.min...window.max).to_a
  end

  def window= r
    super( (r.max-r.min) < 10 ? r : r.min...(r.min+10) )
  end
  
end

# list of lists visible to current user (ListsStreamer)
class ListsCache < ResultsCache

  def items
    @items ||= List.all[@window]
  end
  
  def full_size
    List.count
  end

end

# list's content visible to current user (ListStreamer)
class ListCache < ResultsCache

  def initialize attribs
    @list = List.find attribs[:params][:id].to_i
    super
  end

  def items
    @items ||= @list.entities
  end

  def full_size
    @list.entity_count
  end

end

# list of feeds
class FeedsCache < ResultsCache

  def items
    @items ||= Feed.all[@window]
  end
  
  def full_size
    Feed.count
  end

end

# list of feed items
class FeedCache < ResultsCache

end

# users: list of users visible to current_user (UsersStreamer)
class UsersCache < ResultsCache

  def items
    @items ||= User.all[@window]
  end

  def full_size
    User.count
  end

end

# user's collection visible to current_user (UserCollectionStreamer)
class UserCollectionCache < ResultsCache

end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache

end

# user's recently-viewed list
class UserRecentCache < ResultsCache

end

class TagsCache < ResultsCache

  def initialize attribs
    super
    @tagtype = attribs[:params][:tagtype] if attribs[:params]
  end

  def items
    unless @items
      if @tagtype
        items = Tag.where(tagtype: @tagtype)
      else
        items = Tag.all
      end
      @items = items[@window]
    end
    @items
  end

  def full_size
    Tag.count
  end

  def param sym
    case sym
      when :tagtype
        @tagtype
    end
  end

end

class TagCache < ResultsCache

end

class SitesCache < ResultsCache

  def items
    @items ||= Site.all[@window]
  end

  def full_size
    Site.count
  end

end

class SiteCache < ResultsCache

end

class ReferencesCache < ResultsCache

  def initialize attribs
    super
    @type = 0
    @type = attribs[:params][:type].to_i if attribs[:params] && attribs[:params][:type]
  end

  def klass
    Reference.type_to_class @type
  end

  def items
    @items ||= klass.paginate(:page => (window.min/(window.max-window.min))+1, :per_page => (window.max-window.min))
  end

  def full_size
    klass.count
  end

  def param sym
    case sym
      when :type # Type stored as class
        @type
    end
  end

end

class ReferenceCache < ResultsCache

end

class ReferentsCache < ResultsCache

  def initialize attribs
    super
    @type = 0
    @type = attribs[:params][:type].to_i if attribs[:params] && attribs[:params][:type]
  end

  def klass
    Referent.type_to_class @type
  end

  def items
    @items ||= klass.paginate(:page => (window.min/(window.max-window.min))+1, :per_page => (window.max-window.min))
  end

  def full_size
    klass.count
  end

  def param sym
    case sym
      when :type # Type stored as class
        @type
    end
  end

end

class ReferentCache < ResultsCache

end
