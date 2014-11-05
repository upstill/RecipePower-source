# Object to put a uniform interface on a set of results, whether they
# exist as a scope (if there is no search) or an array of Rcprefs (with search)
class Counts < Hash
  def incr key, amt=1
    key = key.to_a if key.is_a? ActiveRecord::Relation
    if key.is_a? Array
      key.each { |k| self.incr k, amt }
    else
      self[key] = self[key]+amt
    end
  end

  def [](ix)
    super(ix) || 0
  end

  def items sorted=true
    @items ||= self.keys
    @items_sorted ||= self.keys.sort { |rr1, rr2| self[rr2] <=> self[rr1] } if sorted
  end

  def partition bounds
    partition = Partition.new [0]
    # Counts has a complete, non-redundant set of Rcpref records for disparate entities, associated with the number of hits on @querytags
    # We partition the results by the number of @querytags that it matched
    bounds.each do |b|
      if (bound = items.find_index { |v| self[v] < b }) && (bound > partition.last)
        partition.push bound
      end
    end
    partition.push items.count
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
    range = valid_range cur_position..(cur_position+max_window_size)
    range if range.max > range.min
  end

  # Clip a value to the bounds of the partition
  def clip v, range=nil
    if range ||= self[0]..self[-1]
      return range.min if v < range.min
      return range.max if v >= range.max
      v
    end
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
    self.cur_position = clip(cur_position, @window) if @window = valid_range(r)
  end

  def window
    # Memoize @window by calling assignment to ensure that cur_position is in the new bound
    self.window = self[0]..clip(self[0]+max_window_size, self[0]..self[1]) unless @window
    @window
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

end

class ResultsCache < ActiveRecord::Base
  include ActiveRecord::Sanitization
  # The ResultsCache class responds to a query with a series of items.
  # As a model, it saves intermediate results to the database
  self.primary_keys = ["session_id","type"]

  # scope :integers_cache, -> { where type: 'IntegersCache' }
  attr_accessible :session_id, :type, :params, :cache, :partition
  serialize :params
  serialize :cache
  serialize :partition
  attr_accessor :items, :querytags
  delegate :next_range, :window, :next_index, :"done?", :max_window_size, :to => :safe_partition

  # Get the current results cache and return it if relevant. Otherwise,
  # create a new one
  def self.retrieve_or_build session_id, userid, parsed_querytags=[], queryparams={}
    unless parsed_querytags.is_a? Array
      queryparams, parsed_querytags = parsed_querytags, []
    end
    # Convert from ActionController params to hash
    params = { userid: userid } # Keep the id of the viewing user
    self.params_needed.each { |param| params[param] = queryparams[param] if queryparams[param] }

    rc = self.create_with(:params => params).find_or_initialize_by session_id: session_id, type: self.to_s
    # unpack the parameters into instance variables
    params.each { |key, val| rc.instance_variable_set "@#{key}".to_sym, val }
    # A bit of subtlety: we USE the querytags passed in that parameter, NOT the unparsed string from the query params
    # We STORE the unparsed string just because a synthesized tag (with negative ID) doesn't serialize properly
    rc.querytags = parsed_querytags

    if rc.params != params
      # Bust the cache if the params don't match
      rc.cache = rc.partition = rc.items = nil
      rc.params = params
    end
    rc
  end

  # Declare the parameters needed for this class
  def self.params_needed
    [:id, :querytags]
  end

  # Set the current window of attention. Requires start as first parameter; second parameter for limit is optional
  def window= arr
    if arr.is_a? Array
      start, limit = *arr
    else
      start = arr
    end
    oldwindow = safe_partition.window
    safe_partition.window = start..(limit || (start+max_window_size))
    safe_partition.cur_position = start
    # bust the items cache if the window changed
    @items = nil unless (safe_partition.window == oldwindow)
  end

  def max_window_size= n
    safe_partition.max_window_size = n
    self.window = safe_partition.window.min
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
    return (@items = slice_cache) if cache_and_partition
    begin
      # It's possible that the itemscope is an array...
      @items = (itemscope.is_a? Array) ? slice_item_array : slice_item_scope
    rescue  # Fall back to an integer generator
      @items = (safe_partition.window.min...safe_partition.window.max).to_a
    end
  end

  # Return the next item in the current window, incrementing the cur_position
  def next_item
    items && (i = safe_partition.next_index) && items[i] # i is relative to the current window
  end

  def has_query?
    (@querytags.count > 0)
  end

  def ready? # Have the items been sorted out yet?
    (@querytags.count == 0) || cache
  end

  def nmatches # Force the partition and report the first window
    cache_and_partition
    partition[1]
  end

  # Return the total number of items in the result. This doesn't have to be every possible item, just
  # enough to stay ahead of the window.
  def full_size
    return partition[-1] if partition  # Don't create if doesn't exist
    return cache.count if cache
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
    # count_tag is the hook for applying a tag to the current counts
    return (cache != nil) unless self.respond_to? :count_tag
    if @querytags.count == 0
      # No cache required
      self.partition = Partition.new([0, itemscope.count ]) unless partition
      false
    elsif cache
      true
    else
      # Convert the itemscope relation into a hash on entity types
      counts = Counts.new
      @querytags.each { |tag| count_tag tag, counts }

      # Sort the scope by number of hits, descending
      self.cache = counts.items
      bounds = (0...(@querytags.count)).to_a.map { |i| (@querytags.count-i)*30 }
      wdw = partition.window if partition
      self.partition = counts.partition bounds
      self.window = [wdw.min, wdw.max] if wdw
      true
    end
  end

  # This is the real interface, which returns items for display
  # Return a scope or array for the entire collection of items
  def itemscope
    raise 'Abstract Method'
  end

  # Report a previously-saved parameter (or, in fact, any instance variable)
  def param sym
    self.instance_variable_get "@#{sym}".to_sym
  end

  protected

  def slice_cache
    cache.slice( safe_partition.window.min, safe_partition.windowsize )
  end

  def slice_item_scope
    itemscope.limit(safe_partition.windowsize).offset(safe_partition.window.min).to_a
  end

  def slice_item_array
    itemscope.slice( safe_partition.window.min, safe_partition.windowsize )
  end

  # Return the existing partition, if any; otherwise, create one otherwise
  def safe_partition
    if pt = partition
      pt
    else
      self.partition = Partition.new [0, full_size]
    end
  end

end

# Recently-viewed recipes of the given user
class UserCollectionCache < ResultsCache

  def user
    @user ||= User.where(id: @id).first if @id
  end

  # Memoize a query to get all the currently-defined entity types
  def typeset
    @typeset ||= itemscope.select(:entity_type).distinct.order("entity_type DESC").map(&:entity_type)
  end

  # Apply the tag to the current set of result counts
  def count_tag tag, counts
    typeset.each do |type|
      subscope = itemscope.where('rcprefs.entity_type = ?', type)
      # Winnow the scope by restricting the set to Rcprefs referring to recipes in which EITHER
      # * The Rcpref's comment matches the tag's string, OR
      # * The recipe's title matches the tag's string, OR
      # * the recipe is tagged by the tag
      matchstr = tag.normalized_name || Tag.normalizeName(tag.name)
      # r1 = Recipe.joins(:rcprefs).where("recipes.title ILIKE ? and rcprefs.user_id = 3", "%#{matchstr}%")
      # ids1 = subscope.joins("INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%salmon%' and rcprefs.user_id = 3")
      # ids1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%#{matchstr}%' and rcprefs.user_id = 3})
      # ids1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id and recipes.title ILIKE '%#{matchstr}%'}).where("rcprefs.user_id = 3")
      sss1 = subscope.joins(%Q{INNER JOIN recipes ON recipes.id = rcprefs.entity_id}).where("recipes.title ILIKE ?", "%#{matchstr}%")
      sss1 = sss1.where("rcprefs.user_id = #{@id}") if @id
      sss1 = sss1.to_a.uniq { |rr| "#{rr.entity_type}#{rr.entity_id}"}

      sss2 = subscope.find_by_sql( %Q{SELECT * FROM rcprefs where rcprefs.comment ILIKE '%#{matchstr}%'} ).uniq { |rr| "#{rr.entity_type}#{rr.entity_id}"}

      sss3 = subscope.joins("INNER JOIN taggings ON taggings.entity_type = rcprefs.entity_type and taggings.entity_id = rcprefs.entity_id and taggings.tag_id = #{tag.id}")
      sss3 = sss3.to_a.uniq { |rr| "#{rr.entity_type}#{rr.entity_id}" }

      counts.incr sss1 # One extra point for matching in one field
      counts.incr sss2
      counts.incr sss3
      this_round = (sss1+sss2+sss3).uniq
      counts.incr this_round, 30 # Thirty points for matching this tag
    end
  end

  # The sources are a user, a list of users, or nil (for the master global list)
  def sources
    user.id
  end

  def itemscope
    user.collection_scope(:sortby => :collected) if user
  end

end

# An IntegersCache presents the default ResultsCache behavior: no scope, no cache, degenerate partition producing successive integers
class IntegersCache < ResultsCache

end

# list of lists visible to current user (ListsStreamer)
class ListsCache < ResultsCache

  def self.params_needed
    # The access parameter filters for private and public lists
    super + [:access]
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
    return cache if cache
    if list = List.find(@id)
      self.cache = list.entities
    end
  end

end

# list of feeds
class FeedsCache < ResultsCache

  def itemscope
    Feed.unscoped
  end

  def count_tag tag, counts
    matchstr = tag.normalized_name || Tag.normalizeName(tag.name)

    sourcetags = Tag.where(tagtype: 6).where('normalized_name ILIKE ?', "%#{matchstr}%")
    referent_ids = sourcetags.map(&:referent_id)
    site_ids = Site.where(referent_id: referent_ids).map(&:id)
    tagset = Feed.where(site_id: site_ids)

    tagset = tagset.map(&:id)
    tagset = (tagset + tag.feeds.map(&:id)).uniq if tag.id > 0
    matchset = Feed.where("title ILIKE ? or description ILIKE ?", "%#{matchstr}%", "%#{matchstr}%").map(&:id)
    counts.incr tagset.uniq # One extra point for matching in one field
    counts.incr matchset
    this_round = (tagset+matchset).uniq
    counts.incr this_round, 30 # Thirty points for matching this tag
  end

  # The cache is just item keys
  def slice_cache
    Feed.find cache.slice(safe_partition.window.min, safe_partition.windowsize)
  end

end

# list of feed items
class FeedCache < ResultsCache

  def itemscope
    FeedEntry.where(feed_id: @id).order('published_at DESC')
  end

  def count_tag tag, counts
    matchstr = tag.normalized_name || Tag.normalizeName(tag.name)

    sourcetags = Tag.where('normalized_name ILIKE ?', "%#{matchstr}%")
    idlist = sourcetags.map(&:id).to_s
    tagset = itemscope.joins(:taggings)
      .where("feed_entries.id = taggings.entity_id
          AND taggings.entity_type = 'FeedEntry'")
      .where("taggings.tag_id" => idlist).to_a
    matchset = itemscope.where("name ILIKE ? or summary ILIKE ?", "%#{matchstr}%", "%#{matchstr}%").to_a
    counts.incr tagset # One extra point for matching in one field
    counts.incr matchset
    this_round = (tagset+matchset).uniq
    counts.incr this_round, 30 # Thirty points for matching this tag
  end

end

# users: list of users visible to current_user (UsersStreamer)
class UsersCache < ResultsCache

  def itemscope
    User.unscoped
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
    user ? Rcpref.where('private = false OR rcprefs.user_id = ?', user.id) : Rcpref.where(private: false)
  end

end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache

  def itemscope
    user.lists.where( owner_id: id) if user
  end

end

class TagsCache < ResultsCache

  def self.params_needed
    super + [:tagtype]
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

  def self.params_needed
    super + [:type]
  end

  def typenum
    @type ? @type.to_i : 0
  end

  def typeclass
    Reference.type_to_class(typenum).to_s
  end

  def itemscope
    (typeclass == Reference) ? Reference.unscoped : Reference.where(type: typeclass)
  end

end

class ReferenceCache < ResultsCache

end

class ReferentsCache < ResultsCache

  def self.params_needed
    super + [:type]
  end

  def typenum
    @type ? @type.to_i : 0
  end

  def typeclass
    Referent.type_to_class(typenum).to_s
  end

  def itemscope
    (typeclass == Referent) ? Referent.unscoped : Referent.where(type: typeclass)
  end

end

class ReferentCache < ResultsCache

end
