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
    ((rc = self.find_by session_id: session_id) && (rc.params == params)) ?
        rc :
        self.type(params).new( session_id: session_id, querytags: querytags, params: params)
  end

  # Derive the class of the appropriate cache handler from the controller, action and other parameters
  def self.type params
    controller = (params[:controller] || "").singularize.capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == "index")
    controller = controller + params[:owned].to_s.capitalize if params[:action] && (params[:action] == "showowned")
    Object.const_defined?(name = controller+"Cache") || (name = "ResultsCache")
    name.constantize
  end

  def next_item
    raise 'Abstract Method'
  end

  # Must define a query to filter results
  def query
    raise 'Abstract Method'
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
  end

  def items
    @items ||= setup
    @items
  end

  def done?
    @item_index >= window.max
  end

  protected

  # Get the index of the next element, subject to the constraints of the current window,
  # optionally incrementing the current position
  def next_index hold=false
    if cur_position < window.max
      result = cur_position
      self.cur_position = cur_position + 1 unless hold
      result
    end
  end

  def setup
    (window.min...window.max).to_a
  end

end

class IntegersCache < ResultsCache
  # This is a brain-dead integer generator

  def items
    (window.min...window.max).to_a
  end

  def next_item
    next_index
  end

end

# list of lists visible to current user (ListsStreamer)
class ListsCache < ResultsCache

  def items
    @items ||= List.all
  end

  def next_item
    items[next_index]
  end

  def query
    "/lists"
  end

end

# list's content visible to current user (ListStreamer)
class ListCache < ResultsCache

end

# list of feeds
class FeedsCache < ResultsCache

end

# list of feed items
class FeedCache < ResultsCache

end

# users: list of users visible to current_user (UsersStreamer)
class UsersCache < ResultsCache

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

end

class TagCache < ResultsCache

end

class SitesCache < ResultsCache

end

class ReferencesCache < ResultsCache

end

class ReferenceCache < ResultsCache

end

class ReferentsCache < ResultsCache

end

class ReferentCache < ResultsCache

end
