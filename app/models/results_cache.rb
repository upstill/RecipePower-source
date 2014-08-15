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
  def self.retrieve_or_build session_id, userid, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    ((rc = self.find_by session_id: session_id) && (rc.class == self) && (rc.params == params)) ?
        rc :
        self.new( session_id: session_id, params: params.merge( { querytags: querytags, userid: userid } ) )
  end

  # Derive the class of the appropriate cache handler from the controller, action and other parameters
  def self.type params
    controller = (params[:controller] || "").singularize.capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == "index")
    Object.const_defined?(name = controller+"Cache") || (name = "ResultsCache")
    name.constantize
  end
  
  def initialize attribs
    super # Let ActiveRecord take care of initializing attributes
    self.limit = full_size # Figure the maximum extent of the results
    if attribs[:params]
      @userid = attribs[:params][:userid]
      @querytags = attribs[:params][:querytags]
    end
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

  # Take a window of items from the scope
  def item_window scope
    scope.paginate(:page => (window.min/(window.max-window.min))+1, :per_page => (window.max-window.min))
  end

  def items
    return @items if @items
    is = itemscope
    @items = (is.class == Array) ? is : item_window(is)
  end

  # This is the real interface, which returns items for display
  # Return a paginatable scope for the collection of items in the current window
  def itemscope
    raise 'Abstract Method'
  end

  # Return the query that will be augmented with querytags to filter this stream
  def query
    raise 'Abstract Method'
  end

  # Strictly speaking, an abstract method, but returns nil if param doesn't exist
  def param sym
=begin
    case sym
      when :<symval>
        @<symval>
    end
=end
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

  def initialize attribs
    super

    # The access parameter filters for private and public lists
    @access = attribs[:params][:access] if attribs[:params]
  end

  # A listcache may define an itemscope to let the superclass#items method do pagination
  def itemscope
    case @access
      when "private"
        List.where owner_id: @userid
      when "friends"
        List.where availability: 1
      when "public"
        List.where owner_id: User.super_id
      else
        List.all
    end
  end
  
  def full_size
    itemscope.count
  end

  def param sym
    case sym
      when :access
        @access
    end
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

# Recently-viewed recipes of the given user
class UserCollectionCache < ResultsCache

  def initialize attribs
    super
    @user = User.where(id: attribs[:params][:id].to_i).first
  end

  def itemscope
    @user && @user.collection_scope( :sortby => :collected)
  end

  def items
    # The scope from rcprefs needs to be mapped to items after windowing
    @items ||= (rcpref_items = item_window itemscope) && rcpref_items.map(&:recipe)
  end

end

# user's collection visible to current_user (UserCollectionStreamer)
class UserRecentCache < UserCollectionCache

  def itemscope
    @user && @user.collection_scope(all: true)
  end
end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache

end

class TagsCache < ResultsCache

  def initialize attribs
    @tagtype = attribs[:params][:tagtype] if attribs[:params]
    super
  end

  def itemscope
    @tagtype ? Tag.where(tagtype: @tagtype) : Tag.all
  end

  def full_size
    itemscope.count
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

  def itemscope
    klass
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
