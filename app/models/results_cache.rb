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

  # Return the next item, incrementing the cur_position
  def next_item
    if i = next_index
      items[i]
    end
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
    @items ||= List.all
  end

end

# list's content visible to current user (ListStreamer)
class ListCache < ResultsCache

end

# list of feeds
class FeedsCache < ResultsCache

  def items
    @items ||= Feed.all
  end

end

# list of feed items
class FeedCache < ResultsCache

end

# users: list of users visible to current_user (UsersStreamer)
class UsersCache < ResultsCache

  def items
    @items ||= User.all
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

  def items
    @items ||= Tag.all
  end

end

class TagCache < ResultsCache

end

class SitesCache < ResultsCache

  def items
    @items ||= Site.all
  end

end

class ReferencesCache < ResultsCache

  def items
    @items ||= Reference.all
  end

end

class ReferenceCache < ResultsCache

end

class ReferentsCache < ResultsCache

  def items
    @items ||= Referent.all
  end

end

class ReferentCache < ResultsCache

end
