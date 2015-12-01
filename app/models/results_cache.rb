require 'rcpref.rb'
require 'result_type.rb'

# Object to put a uniform interface on a set of results, whether they
# exist as a scope (if there is no search) or an array of Rcprefs (with search)
class Counts < Hash
  def incr key, incr=1
    if key.is_a? ActiveRecord::Relation
      # Late-breaking conversion of scope into items
      modelname = key.model.to_s
      key.pluck(:id).each { |id| self[modelname+'/'+id.to_s] += incr }
    elsif key.is_a? Array
      key.each { |k| self.incr k, incr }
    else
      self[key] += incr
    end
  end

  # Bump the count of all hits across a scope using the id attribute
  def incr_by_scope scope_or_scopes, incr=1
    (scope_or_scopes.is_a?(Array) ? scope_or_scopes : [scope_or_scopes]).each { |scope|
      incr scope, incr
    }
  end

  def [](ix)
    super(ix) || 0
  end

  def itemstubs sorted=true
    @itemstubs ||= sorted ? self.keys.sort { |k1, k2| self[k1] <=> self[k2] } : self.keys
  end

  def partition bounds
    partition = Partition.new [0]
    # Counts has a complete, non-redundant set of model/id records for disparate entities, associated with the number of hits on @querytags
    # We partition the results by the number of @querytags that it matched
    bounds.each do |b|
      if (bound = itemstubs.find_index { |v| self[v] < b }) && (bound > partition.last)
        partition.push bound
      end
    end
    partition.push itemstubs.count
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

# A mixin for ResultsCaches responding to the User controller
module UserFunc

  def user
    @user ||= User.find @id
  end

end

# Prototype of scope definitions and methods for a ResultsCache. These are stubs which do nothing
module NullCache

  # Every meaningful ResultsCache MUST define an itemscope for the base set of results
  # Return a scope or array for the entire collection of items
  def itemscope
    raise 'Abstract Method itemscope'
  end

  # Allowing for the possibility of redundant items that are nonetheless significant for searching,
  # the redundant itemscope may need be retained (e.g., in the case of searching tagging-based scopes)
  # This method may be overridden to
  def uniqueitemscope
    itemscope
  end

  # Provide the uniqueitemscope with a query for ordering the items. Defaults to no response
  def ordereditemscope
    uniqueitemscope
  end

  def scope_count
    uniqueitemscope.size
  end

  def stream_id
    "#{itemscope.model.to_s}-#{@id}"
  end

  # This is a prototypical count_tag method, which digests the itemscope in light of a tag,
  # incrementing the counts appropriately
  def count_tag tag, counts
    raise 'Abstract Method count_tag  '
  end

  # When taking a slice out of the taggings/rcprefs, load the associated entities meanwhile
  def item_scope_for_loading scope
    scope
  end

end

# ...for a ResultsCache based on a table of a particular model
module EntitiesCache

=begin
# Failing to define an itemscope will produce an error from NullCache
  def itemscope
  end
=end

  # This is a prototypical count_tag method, which digests the itemscope in light of a tag,
  # incrementing the counts appropriately
  def count_tag tag, counts
    tagname = tag.normalized_name || Tag.normalizeName(tag.name)
    model = itemscope.model
    if model.reflect_on_association :tags
      counts.incr_by_scope itemscope.joins(:tags).where('"tags"."normalized_name" ILIKE ?', "%#{tagname}%") # One extra point for matching in one field
      counts.incr_by_scope itemscope.joins(:tags).where('"tags"."normalized_name" = ?', tagname), 10 # Extra points for complete matches
    end
    if model.respond_to? :strscopes
      counts.incr_by_scope model.strscopes("%#{tagname}%")
      counts.incr_by_scope model.strscopes(tagname), 10
    end
  end

end

# Methods and defaults for a ResultsCache based on a user's collection
# @id parameter denotes the user
module CollectionCache
  include UserFunc
  include ResultTyping

  def itemscope
    @itemscope ||= user.collection_scope( { :in_collection => true }.merge result_type.entity_params)
  end

  # Provide the uniqueitemscope with a query for ordering the items. Defaults to no response
  def ordereditemscope
    # Use the org parameter and the ASC/DESC attribute to assert an ordering
    case org
      when :ratings
      when :popularity
      when :newest
        sort_attribute = %Q{"#{result_type.table_name}"."created_at"}
        uniqueitemscope.joins(result_type.table_name.to_sym).order("#{sort_attribute} #{@sort_direction || 'DESC'}")
      when :viewed
        uniqueitemscope.order('"rcprefs"."updated_at"' + (@sort_direction || 'DESC'))
      when :random
    end || super
  end

  # Return
  def strscopes matcher, modelclass
    if modelclass.respond_to? :strscopes
      modelclass.strscopes(matcher).collect { |innerscope|
        innerscope = innerscope.joins(:user_pointers).where('"rcprefs"."user_id" = ? and "rcprefs"."in_collection" = true', @id.to_s)
        innerscope = innerscope.where('"rcprefs"."private" = false') unless @id == @viewerid # Only non-private entities if the user is not the viewer
        innerscope
      }
    else
      []
    end
  end

  # Apply a tag to the current set of result counts
  def count_tag tag, counts
    matchstr = "%#{tag.name}%"
    typeset.each do |type|
      modelclass = type.constantize
      scope = modelclass.joins :user_pointers
      scope = scope.where('"rcprefs"."user_id" = ? and "rcprefs"."in_collection" = true', @id.to_s)
      scope = scope.where('"rcprefs"."private" = false') unless @id == @viewerid # Only non-private entities if the user is not the viewer

      # First, match on the comments using the rcpref
      counts.incr_by_scope scope.where('"rcprefs"."comment" ILIKE ?', matchstr)

      # Now match on the entity's relevant string field(s), for which we defer to the class
      strscopes("%#{tag.name}%", modelclass).each { |innerscope| counts.incr_by_scope innerscope }
      strscopes(tag.name, modelclass).each { |innerscope| counts.incr_by_scope innerscope, 30 }

      subscope = modelclass.joins(:taggings).where 'taggings.tag_id = ?', tag.id.to_s
=begin
      # TODO: We're not filtering by user taggings (the more the merrier)
      if @id
        subscope = subscope.where 'taggings.user_id = ?', @id.to_s
      end
=end
      counts.incr_by_scope subscope, 1
    end
  end

protected

  # Memoize a query to get all the currently-defined entity types
  def typeset
    @typeset ||=
        case modelname = itemscope.model.to_s
          when 'Rcpref'
            itemscope.
                select(:entity_type).
                distinct.
                pluck(:entity_type).
                sort
          else
            [ modelname ]
        end
  end

end

module TaggingCache

  # module Uniquify
  # Allowing for the possibility of redundant items that are nonetheless significant for searching,
  # the redundant itemscope may need to be retained (e.g., in the case of searching tagging-based scopes)
  # while the final presentation (and initial count) are without redundancy.
  # NB This happens to work for both collections (based on Rcpref) and taggings b/c both have
  # polymorphic 'entity' associations
  def uniqueitemscope
    itemscope.select("DISTINCT ON (entity_type, entity_id) *")
  end

  def scope_count
    # To avoid loading the relation, we construct a count query from the scope query
    scope_query = uniqueitemscope.to_sql
    sql = %Q{ SELECT COUNT(*) from (#{scope_query}) as internalQuery }
    res = ActiveRecord::Base.connection.execute sql
    res.first["count"].to_i
  end

  # When taking a slice out of the taggings/rcprefs, load the associated entities meanwhile
  def item_scope_for_loading scope
    scope.includes :entity
  end

  # Apply the tag to the current set of result counts
  def count_tag tag, counts
    # Intersect the scope with the set of entities tagged with tags similar to the given tag
    counts.incr itemscope.where(tag_id: TagServices.new(tag).similar_ids) # One extra point for matching in one field

    counts.incr TaggingServices.match tag.name, itemscope # Returns an array of Tagging objects

  end
end

class ResultsCache < ActiveRecord::Base
  include ActiveRecord::Sanitization
  include NullCache

  before_save do
    session_id != nil
  end
  # The ResultsCache class responds to a query with a series of items.
  # As a model, it saves intermediate results to the database
  self.primary_keys = ['session_id', 'type']

  attr_accessible :session_id, :type, :params, :cache, :partition
  serialize :params
  serialize :cache
  serialize :partition
  attr_accessor :items, :querytags, :admin_view, :result_type
  delegate :window, :next_index, :'done?', :max_window_size, :to => :safe_partition

  # Get the current results cache and return it if relevant. Otherwise,
  # create a new one
  def self.retrieve_or_build session_id, parsed_querytags=[], params={}
    unless parsed_querytags.is_a? Array
      params, parsed_querytags = parsed_querytags, []
    end

    result_type = ResultType.new params['result_type']
    # The choice of handling class, and thus the cache, is a function of the result type required as well as the controller/action pair
    if cc = self.cache_class(params['controller'], params['action'], result_type)

      # Since params_needed may have key/default pairs as well as a list of names
      defaulted_params = HashWithIndifferentAccess.new
      paramlist = cc.params_needed.collect { |pspec|
        if pspec.is_a? Array
          defaulted_params[pspec.first] = pspec.last
          pspec.first
        else
          pspec
        end
      }.uniq
      # relevant_params are the parameters that will bust the cache when changed
      relevant_params = defaulted_params.merge(params).slice *(paramlist - ['result_type']).uniq
      rc = cc.create_with(:params => relevant_params).find_or_initialize_by session_id: session_id, type: cc.to_s
      # unpack the parameters into instance variables
      relevant_params.each { |key, val|
        rc.instance_variable_set "@#{key}".to_sym, ((val.is_a?(String) && (val.to_i.to_s == val)) ? val.to_i : val)
      }
      # A bit of subtlety: we USE the querytags passed in that parameter, NOT the unparsed string from the query params
      # We STORE the unparsed string just because a synthesized tag (with negative ID) doesn't serialize properly
      rc.querytags = parsed_querytags
      rc.result_type = result_type # Because we want access to the result type's services, not just a string

      # For purposes of busting the cache, we assume that sort direction is irrelevant
      if rc.params.except(:sort_direction) != relevant_params.except(:sort_direction) # TODO: Take :nocache into consideration
        # Bust the cache if the params don't match
        rc.cache = rc.partition = rc.items = nil
        rc.params = relevant_params
      end
      rc
    end
  end

  # Return the subclass of ResultsCache that will handle generating items
  def self.cache_class controller, action, result_type
    # Here's the chance to divert handling to different cache generators
    classname = controller.camelize + action.capitalize + 'Cache'
    if klass = (classname.constantize rescue nil)
      # Give the class a chance to defer to a subclass based on the result type
      klass = klass.subclass_for(result_type) if klass.respond_to? :subclass_for
    else
      logger.debug 'No ResultsCache handler ' + classname
    end
    klass
  end

  def self.bust session_id
    self.where(session_id: session_id).each { |rc| rc.destroy }
  end

  # Declare the parameters needed for this class
  def self.params_needed
    [:id, :viewerid, :admin_view, :querytags, [:org, :viewed], :sort_direction ]
  end

  def viewer
    @viewer ||= User.find @viewerid
  end

  def org
    @org.to_sym
  end

  # Return the following range, for triggering purposes, and optionally pre-advance the window
  def next_range force=false
    if (range = safe_partition && safe_partition.next_range) && force
      self.window = [range.min, range.max]
    end
    range
  end

  # Set the current window of attention. Requires start as first parameter; second parameter for limit is optional
  def window= arr
    if arr.is_a? Array
      start, limit = *arr
    else
      start = arr
    end
    oldwindow = safe_partition.window
    if !limit
      self.cache = nil
      self.partition = nil
      self.items = nil
      limit = start + max_window_size
    end
    safe_partition.window = start..limit
    safe_partition.cur_position = start
    # bust the items cache if the window changed
    @items = nil unless (safe_partition.window == oldwindow)
    save
  end

  def max_window_size= n
    safe_partition.max_window_size = n
    self.window = safe_partition.window.min
  end

  # Derive the class of the appropriate cache handler from the controller, action and other parameters
  def self.type params
    controller = (params[:controller] || '').singularize.capitalize
    controller = controller.pluralize if params[:action] && (params[:action] == 'index')
    name = "#{controller}Cache"
    Object.const_defined?(name) ? name.constantize : ResultsCache
  end

  # Take a window of entities from the scope or the results cache
  def items
    @items ||=
    if cache_and_partition
      slice_cache
    elsif itemscope.is_a? Array
      itemscope.slice safe_partition.window.min, safe_partition.windowsize
    else
      item_scope_for_loading(
        ordereditemscope.limit(safe_partition.windowsize).offset(safe_partition.window.min)
      ).to_a
    end
  end

  # Return the next item in the current window, incrementing the cur_position
  def next_item
    if items
      if i = safe_partition.next_index
        @items[i] # i is relative to the current window
      end
    end
  end

  def has_query?
    (@querytags ||= []).count > 0
  end

  def ready? # Have the items been sorted out yet?
    ((@querytags ||= []).count == 0) || cache
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
      scope_count
    rescue Exception => e
      1000000
    end
  end

  # Convert the scope to a cache of entries, as needed. In the default case, this is only
  # necessary if there is a query. Otherwise, the cache remains empty and items are taken
  # from the scope as partitioning dictates.
  def cache_and_partition
    # count_tag is the hook for applying a tag to the current counts
    return (cache != nil) unless self.respond_to? :count_tag
    if (@querytags ||= []).count == 0
      # Straight passthrough of the itemscope => no cache required
      self.partition ||= Partition.new([0, scope_count ])
      false
    elsif cache
      true
    else
      # Convert the itemscope relation into a hash on entity types
      counts = Counts.new
      @querytags.each { |tag| count_tag tag, counts }

      # Sort the scope by number of hits, descending
      self.cache = counts.itemstubs
      bounds = (0...(@querytags.count)).to_a.map { |i| (@querytags.count-i)*30 } # Partition according to the # of matches
      wdw = partition.window if partition
      self.partition = counts.partition bounds
      self.window = [wdw.min, wdw.max] if wdw
      true
    end
  end

  # Report a previously-saved parameter (or, in fact, any instance variable)
  def param sym
    self.instance_variable_get "@#{sym}".to_sym
  end

  protected

  # Convert from item stubs (modelname + id) to entities, in the most efficient manner possible
  def slice_cache
    cache_slice = cache.slice safe_partition.window.min, safe_partition.windowsize

    # First, create a hash of arrays, indexed by modelname, to collect the ids for that model
    records = { }
    cache_slice.each { |itemspec|
      modelname, id = *itemspec.split('/')
      records[modelname] = (records[modelname] || []) << id.to_i
    }

    # Now bulk-load all the records for each model type, replacing the id array with the corresponding array of records
    records.keys.each { |modelname|
      # Convert the ids to objects in one go
      records[modelname] = modelname.constantize.where(id: records[modelname]).to_a
    }

    # Finally convert the original, ordered array of item specs to the corresponding array of records (also ordered)
    cache_slice.collect { |itemspec|
      modelname= itemspec.split('/').first
      records[modelname].shift
    }
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

class SearchIndexCache < ResultsCache
  include ResultTyping
  include EntitiesCache

  def stream_id
    'search'
  end

end

# Cache for facets of a user's collection, in fact just a stub for selecting other classes
class UsersShowCache < ResultsCache
  include ResultTyping

  # Different subclasses are used to handle different result types
  def self.subclass_for result_type
    case result_type
      when 'lists'
        UserListsCache
      when 'lists.collected'
        UserCollectedListsCache
      when 'lists.owned'
        UserOwnedListsCache
      when 'friends'
        UserFriendsCache
      when 'feeds'
        UserFeedsCache
      else
        UsersCollectionCache
    end
  end

end

class UsersCollectionCache < ResultsCache
  include CollectionCache

  # The CollectionCache module defines the default itemscope on a user's collection,
  # appropriately using the result_type parameter
end

# user's collection visible to current_user (UserCollectionStreamer)
class UsersRecentCache < UsersCollectionCache

end

# user's collection visible to viewer (UserCollectionStreamer)
class UsersBiglistCache < UsersCollectionCache

  def itemscope
    @itemscope ||=
        Rcpref.where('private = false OR "rcprefs"."user_id" = ?', @viewerid).
            where.not(entity_type: %w{ Feed User List})
  end
end

class UserFeedsCache < UsersCollectionCache

  def ordereditemscope
    if @org && (@org.to_sym == :newest)
      uniqueitemscope.joins(:feeds).order('"feeds"."last_post_date"' + (@sort_direction || 'DESC'))
    else
      super
    end
  end

end


# Provide the set of lists the user has collected, but only those visible to her
class UserCollectedListsCache < ResultsCache
  include UserFunc
  include EntitiesCache

  def itemscope
    @itemscope ||= ListServices.lists_collected_by user, viewer
  end
end

# Provide the set of lists the user has collected
class UserOwnedListsCache < ResultsCache
  include UserFunc
  include EntitiesCache

  def itemscope
    @itemscope ||= ListServices.lists_owned_by user, viewer
  end

  def ordereditemscope
    case org
      when :ratings
      when :popularity
      when :newest
      when :viewed
        uniqueitemscope.order('"rcprefs"."updated_at"' + (@sort_direction || 'DESC'))
      when :random
    end || super
  end
end

# An IntegersCache presents the default ResultsCache behavior: no scope, no cache, degenerate partition producing successive integers
class IntegersCache < ResultsCache
  def itemscope
    (0..30).to_a
  end
end

# list of lists visible to the viewer
class ListsIndexCache < ResultsCache
  include EntitiesCache

  # A listcache may define an itemscope to let the superclass#items method do pagination
  def itemscope
    @itemscope ||=
    case result_type.subtype
      when 'owned'
        ListServices.lists_owned_by user, viewer
      when 'collected'
        ListServices.lists_collected_by user, viewer
      when 'all'
        List.unscoped
      else # By default, we only see lists belonging to our friends and Super that are not private, and all those that are public
        ListServices.lists_visible_to viewer
    end
  end
end

# list's content visible to current user (ListStreamer)
class ListsShowCache < ResultsCache
  include TaggingCache

  def list
    @list ||= List.find @id
  end

  # The itemscope is the initial query for all possible items, subject to subqueries via count_tag
  def itemscope
    @itemscope ||= ListServices.new(list).tagging_scope @viewerid
  end

  def stream_id
    "list_#{@id}_contents"
  end

end

# list of feeds
class FeedsIndexCache < ResultsCache
  include EntitiesCache

  def self.params_needed
    super + [ [:org, :newest] ]
  end

  def itemscope
    @itemscope ||=
    case result_type.subtype
      when 'collected' # Feeds actually collected by user and friends
        persons_of_interest = [@viewerid, 1, 3, 5].map(&:to_s).join(',')
        Feed.joins(:user_pointers).
            where("rcprefs.user_id in (#{persons_of_interest})").
            order("rcprefs.user_id DESC").   # User's own feeds first
            order("rcprefs.updated_at DESC") # Most recent first (within user)
      when 'all' # For admins only: every feed in the world
        Feed.order 'approved DESC'
      when 'approved' # Default: normal user view for shopping for feeds (only approved feeds)
        Feed.where approved: true
      else
        admin_view ? Feed.unscoped : Feed.where(approved: true)
    end
  end

  def ordereditemscope
    case @org.to_sym
      when :newest
        uniqueitemscope.order('"feeds"."last_post_date" ' + (@sort_direction || 'DESC'))
      when :approved
        uniqueitemscope.order('"feeds"."approved" ' + (@sort_direction || 'ASC'))
      else
        super
    end
  end

end

# list of feed items
class FeedsOwnedCache < ResultsCache
  include EntitiesCache

  def feed
    @feed ||= Feed.find @id
  end

  def itemscope
    @itemscope ||= feed.feed_entries
  end

end

# users: list of users visible to current_user (UsersStreamer)
class UsersIndexCache < ResultsCache
  include EntitiesCache

  def itemscope
    @itemscope ||=
    if admin_view # See everyone in admin view
      User.unscoped
    else
      case result_type.subtype
        when 'followees'
          viewer.followees
        when 'relevant'
          # Exclude the viewer and all their friends
          User.where(private: false).
              where('count_of_collecteds > 0').
              where.not( id: viewer.followee_ids+[@viewerid, 4, 5] ).
              order('count_of_collecteds DESC')
        else
          User.where(private: false).where.not(id: [4, 5])
      end
    end
  end

end

class UserFriendsCache < ResultsCache
  include EntitiesCache
  include UserFunc

  def itemscope
    @itemscope ||= user.followees
  end

end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache
  include EntitiesCache
  include UserFunc

  def itemscope
    @itemscope ||= user.owned_lists
  end

end

class TagsIndexCache < ResultsCache
  include EntitiesCache

  def self.params_needed
    super + [:tagtype]
  end

  # Tags don't go through Taggings, so we just use/count them directly
  def count_tag tag, counts
    super # Do the usual strscopes thing
    counts.incr_by_scope itemscope.where(normalized_name: tag.normalized_name || Tag.normalizeName(tag.name)), 30
  end

  def itemscope
    @itemscope ||= @tagtype ? Tag.where(tagtype: @tagtype) : Tag.unscoped
  end

end

class TagsAssociatedCache < ResultsCache
  include TaggingCache

  def tag
    @tag ||= Tag.find @id
  end

  def itemscope
    @itemscope ||= tag.taggings
  end

end

class SitesIndexCache < ResultsCache
  include EntitiesCache

  def itemscope
    @itemscope ||= Site.unscoped
  end

end

class SiteCache < ResultsCache
  include ResultTyping
  include EntitiesCache

  def site
    @site = Site.find @id
  end

  def itemscope
    @itemscope ||= site.contents_scope result_type.model_name
  end
end

class ReferencesIndexCache < ResultsCache
  include EntitiesCache

  def self.params_needed
    super + [:type]
  end

  def type
    @type ||= 0
  end

  def typeclass
    Reference.type_to_class(type).to_s
  end

  def itemscope
    @itemscope ||= (typeclass == Reference) ? Reference.unscoped : Reference.where(type: typeclass)
  end

end

class ReferenceCache < ResultsCache

  def reference
    @reference ||= Reference.find @id
  end

end

class ReferentsIndexCache < ResultsCache
  include EntitiesCache

  def self.params_needed
    super + [:type]
  end

  def type
    @type ||= 0
  end

  def typeclass
    Referent.type_to_class(type).to_s
  end

  def itemscope
    @itemscope ||= (typeclass == Referent) ? Referent.unscoped : Referent.where(type: typeclass)
  end

end

class ReferentCache < ResultsCache

end
