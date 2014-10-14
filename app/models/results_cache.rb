# Object to put a uniform interface on a set of results, whether they
# exist as a scope (if there is no search) or an array of Rcprefs (with search)
class Counts < Hash
  def incr key, amt=1
    if key.is_a? Array
      key.each { |k| self.incr k, amt }
    else
      self[key] = self[key]+amt
    end
  end

  def [](ix)
    super(ix) || 0
  end

end

class RcprefsSorted < Object

  def initialize sco, tags
    if tags.empty?
      @scope = sco
    else
      # Convert the sco relation into a hash on entity types
      typeset = sco.select(:entity_type).distinct.order("entity_type DESC").map(&:entity_type)
      counts = Count.new
      typeset.each do |type|
        subscope = sco.where('rcprefs.entity_type = ?', type)
        tags.each do |tag|
          # Winnow the scope by restricting the set to Rcprefs referring to recipes in which EITHER
          # * The Rcpref's comment matches the tag's string, OR
          # * The recipe's title matches the tag's string, OR
          # * the recipe is tagged by the tag
          matchstr = tag.normalized_name
          # r1 = Recipe.joins(:rcprefs).where("recipes.title ILIKE ? and rcprefs.user_id = 3", "%#{matchstr}%")
          # ids1 = subscope.joins("INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%salmon%' and rcprefs.user_id = 3")
          # ids1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%#{matchstr}%' and rcprefs.user_id = 3})
          # ids1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%#{matchstr}%'}).where("rcprefs.user_id = 3")
          sss1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id}).where("recipes.title ILIKE ?", "%#{matchstr}%").where("rcprefs.user_id = 3")
          sss2 = subscope.find_by_sql %Q{SELECT * FROM rcprefs where rcprefs.comment ILIKE '%#{matchstr}%'}
          sss3 = subscope.joins("INNER JOIN taggings ON taggings.entity_type = rcprefs.entity_type and taggings.entity_id = rcprefs.entity_id and taggings.tag_id = 283")
          counts.incr sss1
          counts.incr sss2
          counts.incr sss3
          this_round = sss1+sss2+sss3
          counts.incr this_round, 30
        end
      end
      @scope = this_round
    end
  end

  # Sort the results array by the counts for each
  def sort_results counts

  end
end

# A partition is an array of offsets within another array or a scope, denoting the boundaries of groups
# for streaming.  
class Partition < Array
  attr_accessor :cur_position, :window, :max_window_size

  def windowsize
    window.max-window.min
  end

  def max_window_size
    @max_window_size ||= 10
  end

  # Provide the stream parameter for the "next page" link. Will be null if we've passed the window
  def next_range
    valid_range cur_position..(cur_position+max_window_size)
  end

  # Clip a value to the bounds of the partition
  def clip v, range=nil
    if range ||= self[0]..self[-1]
      return range.min if v < range.min
      return range.max if v >= range.max
      v
    end
  end

  def window
    self.window = self[0]..clip(self[0]+max_window_size, self[0]..self[1]) unless @window
    @window
  end

  def cur_position
    @cur_position ||= window.min
  end

  # Clip the given range to valid cells, with an appropriate maximum size
  def valid_range r
    if (lb = clip r.min) && # Returns nil if the range is invalid
        (pr = self.partition_range lb) && # Returns nil if lb is out of range
        (ub = clip r.max, lb..clip(lb+max_window_size, pr))
      lb..ub
    end
  end

    # Set the current window on the partition, confining it to an existing partition
  def window= r
    self.cur_position = @window.min if @window = valid_range(r)
  end

  def done?
    cur_position >= window.max
  end

  # Get the index of the next element, relative to the current window,
  # optionally incrementing the current position
  def next_index hold=false
    if cur_position < window.max
      this_position = cur_position
      self.cur_position = cur_position + 1 unless hold
      this_position - window.min # Relativize the index
    end
  end

=begin
  def pagenum
    (window.min/(window.max-window.min))+1
  end

  def pagesize
    (window.max-window.min)
  end
=end

  # Return the range enclosing ix. Returns an empty range for ix above the partition
  def partition_range ix
    if px = partition_of(ix)
      self[px]..self[px+1]
    elsif ix >= self[-1]
      self[-1]..self[-1]
    end
  end

  # Find the index of the partition containing 'ix', or nil if outside the range
  def partition_of ix
    (self.find_index { |lower_bound| lower_bound > ix } - 1 ) unless (ix < self[0]) or (ix >= self[-1])
  end

=begin
  def self.load str
    unless str.blank?
      # h = YAML.load str
      # p = h[:arr]
      # p.window = h[:window]
      p = YAML.load str
      p
    end
  end

  def self.dump partition
    if partition
      str = YAML.dump arr: partition, window: partition.window
      str = YAML.dump partition
      str
    end
  end
=end
end

class ResultsCache < ActiveRecord::Base
  include ActiveRecord::Sanitization
  # The ResultsCache class responds to a query with a series of items.
  # As a model, it saves intermediate results to the database
  self.primary_key = "session_id"

  # scope :integers_cache, -> { where type: 'IntegersCache' }
  attr_accessible :session_id, :params, :cache, :partition
  serialize :params
  serialize :cache
  serialize :partition # , Partition
  attr_accessor :items, :querytags
  delegate :next_range, :window, :next_index, :"done?", :to => :partition

  def initialize attribs={}
    super # Let ActiveRecord take care of initializing attributes
    # Transfer values from params to instance variables
    (params_needed+[:userid, :id, :querytags]).each { |key|
      self.instance_variable_set("@#{key}".to_sym, attribs[:params][key.to_sym])
    } if attribs[:params]
  end

  # Get the current results cache and return it if relevant. Otherwise,
  # create a new one
  def self.retrieve_or_build session_id, userid, querytags=[], params={}
    if querytags.class == Hash
      params, querytags = querytags, []
    end
    ((rc = self.find_by session_id: session_id) && (rc.class == self) && (rc.params == params)) ?
        rc :
        self.new(session_id: session_id, params: params.merge({querytags: querytags, userid: userid}))
  end

  # Set the current window of attention
  def window=r
    oldwindow = safe_partition.window
    safe_partition.window=r
    # bust the items cache if the window is different
    @items = nil unless (safe_partition.window == oldwindow)
  end

  # Derive the class of the appropriate cache handler from the controller, action and other parameters
  def self.type params
    controller = (params[:controller] || "").singularize.capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == "index")
    name = "#{controller}Cache"
    Object.const_defined?(name) ? name.constantize : ResultsCache
  end

  # Take a window of items from the scope or the results cache
  def items
    return @items if @items
    return (@items = @cache.slice( safe_partition.window.min, safe_partition.windowsize )) if cache_and_partition
    begin
      # It's possible that the itemscope is an array...
      if itemscope.is_a? Array
        @items = itemscope.slice( safe_partition.window.min, safe_partition.windowsize )
      else
        @items = itemscope.limit(safe_partition.windowsize).offset(safe_partition.window.min).all # :page => safe_partition.pagenum, :per_page => safe_partition.pagesize
      end
    rescue  # Fall back to an integer generator
      @items = (safe_partition.window.min...safe_partition.window.max).to_a
    end
  end

  # Return the next item in the current window, incrementing the cur_position
  def next_item
    if (i = safe_partition.next_index) && items # i is relative to the current window
      items[i]
    end
  end

  # Return the total number of items in the result. This doesn't have to be every possible item, just
  # enough to stay ahead of the window.
  def full_size
    return partition[-1] if partition  # Don't create if doesn't exist
    return @cache.count if @cache
    begin
      itemscope.count
    rescue
      1000000
    end
  end

  # Convert the scope to a cache of entries, as needed. In the default case, this is only
  # necessary if there is a query. Otherwise, the cache remains empty and items are taken
  # from the scope as partitioning dictates.
  def cache_and_partition
    @cache != nil # There is no cache => obtain items from the scope
  end

  # This is the real interface, which returns items for display
  # Return a scope or array for the entire collection of items
  def itemscope
    raise 'Abstract Method'
  end

=begin
  # Return the query that will be augmented with querytags to filter this stream
  def query
    raise 'Abstract Method'
  end
=end

  # Opportunity for subclass to declare a list of parameters to save as instance variables
  def params_needed
    []
  end

  # Report a previously-saved parameter (or, in fact, any instance variable)
  def param sym
    self.instance_variable_get "@#{sym}".to_sym
  end

  protected

  # Return the existing partition, if any; otherwise, create one otherwise
  def safe_partition
    partition || (self.partition = Partition.new [0, full_size])
  end

end

# An IntegersCache presents the default ResultsCache behavior: no scope, no cache, degenerate partition producing successive integers
class IntegersCache < ResultsCache

end

# list of lists visible to current user (ListsStreamer)
class ListsCache < ResultsCache

  def params_needed
    # The access parameter filters for private and public lists
    [:access]
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
        List.unscoped
    end
  end

end

# list's content visible to current user (ListStreamer)
class ListCache < ResultsCache

  def itemscope
    return @cache if @cache
    if list = List.find(@id)
      @cache = list.entities
    end
  end

end

# list of feeds
class FeedsCache < ResultsCache

  def itemscope
    Feed.unscoped
  end

end

# list of feed items
class FeedCache < ResultsCache

  def itemscope
    FeedEntry.where(feed_id: @id).order('published_at DESC')
  end

end

# users: list of users visible to current_user (UsersStreamer)
class UsersCache < ResultsCache

  def itemscope
    User.unscoped
  end

end

# Recently-viewed recipes of the given user
class UserCollectionCache < ResultsCache

  def user
    @user ||= User.where(id: @id).first if @id
  end

  # Transform the item scope into a hash with Rcprefs the key, and values the quality of match of that Rcpref
  def cache_and_partition
    sorted = RcprefsSorted.new itemscope, @querytags
  end

  # The sources are a user, a list of users, or nil (for the master global list)
  def sources
    user.id
  end

  def itemscope
    user.collection_scope(:sortby => :collected) if user
  end

end

# user's collection visible to current_user (UserCollectionStreamer)
class UserRecentCache < UserCollectionCache

  def itemscope
    user.collection_scope(all: true) if user
  end
end

# user's collection visible to current_user (UserCollectionStreamer)
class UserBiglistCache < UserCollectionCache

  def itemscope
    user ? Rcpref.where('private = false OR user_id = ?', user.id) : Rcpref.where(private: false)
  end

end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache

  def itemscope
    user.lists.where( owner_id: id) if user
  end

end

class TagsCache < ResultsCache

  def params_needed
    [:tagtype]
  end

  def itemscope
    @tagtype ? Tag.where(tagtype: @tagtype) : Tag.unscoped
  end

end

class TagCache < ResultsCache

end

class SitesCache < ResultsCache

  def itemscope
    Site.unscoped
  end

end

class SiteCache < ResultsCache

end

class ReferencesCache < ResultsCache

  def params_needed
    [:type]
  end

  def typenum
    @type ? @type.to_s : 0
  end

  def typeclass
    Reference.type_to_class(typenum).to_s
  end

  def itemscope
    Reference.where type: typeclass
  end

end

class ReferenceCache < ResultsCache

end

class ReferentsCache < ResultsCache

  def params_needed
    [:type]
  end

  def typenum
    @type ? @type.to_s : 0
  end

  def typeclass
    Referent.type_to_class(typenum).to_s
  end

  def itemscope
    Referent.where type: typeclass
  end

end

class ReferentCache < ResultsCache

end
