require './lib/querytags.rb'
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
    # Sort the count keys in descending order of hits
    @itemstubs ||= sorted ? self.keys.sort { |k1, k2| self[k2] <=> self[k1] } : self.keys
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

  def initialize range, mws=5
    super range
    self.max_window_size = mws
  end

  def windowsize
    window.max-window.min
  end

  def max_window_size
    @max_window_size ||= 5
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
    @user ||= User.find @entity_id
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
    "#{itemscope.model.to_s}-#{@entity_id}"
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
      strscope = model.strscopes "%#{tag.name}%" do |joinspec=nil|
        joinspec ? ordereditemscope.joins(joinspec) : ordereditemscope
      end
      counts.incr_by_scope strscope
      strscope = model.strscopes tag.name do |joinspec=nil|
        joinspec ? ordereditemscope.joins(joinspec) : ordereditemscope
      end
      counts.incr_by_scope strscope, 10
    end
  end

  # Provide the uniqueitemscope with a query for ordering the items. Defaults to no response
  def ordereditemscope
    # Use the org parameter and the ASC/DESC attribute to assert an ordering
    case org
      when :ratings
      when :popularity
      when :newest
        sort_attribute = %Q{"#{sort_table_name}"."created_at"}
        uniqueitemscope.order("#{sort_attribute} #{@sort_direction || 'DESC'}")
      when :updated
        sort_attribute = %Q{"#{sort_table_name}"."updated_at"}
        uniqueitemscope.order("#{sort_attribute} #{@sort_direction || 'DESC'}")
      when :viewed
        uniqueitemscope.joins(:user_pointers).order('"rcprefs"."updated_at" ' + (@sort_direction || 'DESC'))
      when :random
    end || super
  end

end

# Methods and defaults for a ResultsCache based on a user's collection
# @entity_id parameter denotes the user
module CollectionCache
  include UserFunc
  include ResultTyping

  def itemscope
    # :entity_type => %w{ Recipe Site FeedEntry },
    @itemscope ||= user.collection_scope( { :in_collection => true }.merge result_type.entity_params)
  end

  # Provide the uniqueitemscope with a query for ordering the items. Defaults to no response
  def ordereditemscope
    # Use the org parameter and the ASC/DESC attribute to assert an ordering
    case org
      when :ratings
      when :popularity
      ## when :updated
        ## sort_attribute = %Q{"#{sort_table_name}"."updated_at"}
        ## uniqueitemscope.joins(sort_table_name.to_sym).order("#{sort_attribute} #{@sort_direction || 'DESC'}")
      when :newest
        ## sort_attribute = %Q{"#{sort_table_name}"."created_at"}
        ## uniqueitemscope.joins(sort_table_name.to_sym).order("#{sort_attribute} #{@sort_direction || 'DESC'}")
        uniqueitemscope.order('"rcprefs"."created_at"' + (@sort_direction || 'DESC'))
      when :viewed, :updated
        uniqueitemscope.order('"rcprefs"."updated_at"' + (@sort_direction || 'DESC'))
      when :random
    end || super
  end

  # Return
  def strscopes matcher, modelclass
    if modelclass.respond_to? :strscopes
      modelclass.strscopes(matcher).collect { |innerscope|
        innerscope = innerscope.joins(:user_pointers).where('"rcprefs"."user_id" = ? and "rcprefs"."in_collection" = true', @entity_id.to_s)
        innerscope = innerscope.where('"rcprefs"."private" = false') unless @entity_id == @viewerid # Only non-private entities if the user is not the viewer
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
      scope = scope.where('"rcprefs"."user_id" = ? and "rcprefs"."in_collection" = true', @entity_id.to_s)
      scope = scope.where('"rcprefs"."private" = false') unless @entity_id == @viewerid # Only non-private entities if the user is not the viewer

      # First, match on the comments using the rcpref
      counts.incr_by_scope scope.where('"rcprefs"."comment" ILIKE ?', matchstr)

      # Now match on the entity's relevant string field(s), for which we defer to the class
      strscopes("%#{tag.name}%", modelclass).each { |innerscope| counts.incr_by_scope innerscope }
      strscopes(tag.name, modelclass).each { |innerscope| counts.incr_by_scope innerscope, 30 }

      subscope = modelclass.joins(:taggings).where 'taggings.tag_id = ?', tag.id.to_s
=begin
      # TODO: We're not filtering by user taggings (the more the merrier)
      if @entity_id
        subscope = subscope.where 'taggings.user_id = ?', @entity_id.to_s
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

    counts.incr TaggingServices.match(tag.name, itemscope) # Returns an array of Tagging objects

  end
end

module ExtractParams
  def self.included(base)
    base.extend(ClassMethods)
  end
  module ClassMethods
    def extract_params result_type=nil, params={}
      if result_type.is_a? Hash
        result_type, params = nil, result_type
      end

      # Since params_needed may be key/default pairs as well as a list of names
      defaulted_params = HashWithIndifferentAccess.new
      paramlist = self.params_needed.collect { |pspec|
        if pspec.is_a? Array
          defaulted_params[pspec.first] = pspec.last.to_s # They're recorded as strings, since that's what params use
          pspec.first
        else
          pspec
        end
      }.uniq

      # The entity_id comes in the :id param, but this can cause confusion with the AR id for the record.
      # Consequently, we use :entity_id internally
      defaulted_params[:entity_id] = params[:id] if params[:id]

      # relevant_params are the parameters that will bust the cache when changed from one request to another
      defaulted_params.merge(params).merge(:result_type => result_type || '').slice *paramlist
    end
  end

  private

  # Whenever the params get assigned--whether directly by assignment, by mass-assignment, or by fetching records--we
  # copy the param values into the cache object

  # Do type conversions when accepting instance variables
  def params= params_hash
    defined?(super) ? super : (@params = params_hash.clone)# To handle, e.g., serialization
    params_hash.each { |key, val|
      setter = :"#{key}="
      if self.private_methods.include? setter
        self.send setter, val
      else
        self.instance_variable_set "@#{key}".to_sym, val
      end
    }
  end

  def result_type= rt
    @result_type = ResultType.new rt # Because we want access to the result type's services, not just a string
  end

end

# A NullCache is a shell for handling the case where there ARE no results to manage (eg., in a #show action)
class NullResults
  include NullCache
  include ExtractParams

  attr_reader :params, :admin_view, :querytags

  # Declare the parameters needed for this class
  def self.params_needed
    # [:entity_id, :viewerid, :admin_view, :querytags, [:org, :newest], :sort_direction, [ :result_type, '' ] ]
    [ :admin_view ]
  end

  def initialize params={}
    self.send :'params=', self.class.extract_params(params)
    # We blow off any querytags, but respond with an empty array
    @querytags = []
    @result_type = ResultType.new ''
  end

  def has_query?
    false
  end

end

class ResultsCache < ActiveRecord::Base
  include ActiveRecord::Sanitization
  include NullCache
  include ExtractParams

  before_save do
    session_id != nil
  end

  belongs_to :tags_cache, :foreign_key => :session_id

  # The ResultsCache class responds to a query with a series of items.
  # As a model, it saves intermediate results to the database
  self.primary_keys = ['session_id', 'type', 'result_typestr']

  # Standard parameters
  attr_reader :entity_id, :viewerid, :admin_view, :querytags, :org, :sort_direction, :result_type

  # Declare the parameters needed for this class
  def self.params_needed
    [:entity_id, :viewerid, :admin_view, :querytags, [:org, :newest], :sort_direction, [ :result_type, '' ] ]
  end

  attr_accessible :session_id, :type, :params, :cache, :partition, :result_typestr
  serialize :params
  serialize :cache
  serialize :partition
  attr_accessor :items
  delegate :window, :next_index, :'done?', :max_window_size, :to => :safe_partition

  # Get the current results cache and return it if relevant. Otherwise,
  # create a new one
  def self.retrieve_or_build session_id, result_types, params={}
    result_types.collect { |result_type|
      # The choice of handling class, and thus the cache, is a function of the result type required as well as the controller/action pair

      # Derive the subclass of ResultsCache that will handle generating items
      classname = params['controller'].camelize + params['action'].capitalize + 'Cache'
      if cc = (classname.constantize rescue nil)
        # Give the class a chance to defer to a subclass based on the result type
        cc = cc.subclass_for(result_type) if cc.respond_to? :subclass_for
        
        relevant_params = cc.extract_params result_type, params
        
        rc = cc.find_or_initialize_by(session_id: session_id,
                                      type: cc.to_s,
                                      result_typestr: (relevant_params[:result_type] || ''))
        # For purposes of busting the cache, we assume that sort direction is irrelevant
        # NB: At the point, the params in rc are in exactly the same form as the query params, i.e. strings

        if rc.params != relevant_params # TODO: Take :nocache into consideration
          # Bust the cache if the prior params don't match the new ones
          diffs = (rc.params.keys + relevant_params.keys).uniq.collect { |key|
            "#{key}: #{rc.params[key] || nil}=>#{relevant_params[key] || nil}" if rc.params[key] != relevant_params[key]
          }.compact.join('; ') if rc.params.present?
          diffs = diffs ? "; busted cache on #{diffs}" : '. (new)'

          rc.cache = rc.partition = rc.items = nil
        end

        # Assign the params anyway for side-effects in setting instance variables correctly
        rc.send :'params=', relevant_params

        logger.debug "Started #{cc} for #{rc.result_type.class} #{rc.result_type}#{diffs || '.'}"
        rc
      else # No cacheclass
        logger.debug 'No ResultsCache handler ' + classname
        nil
      end
    }.compact
  end

  def self.bust session_id
    self.where(session_id: session_id).each { |rc| rc.destroy }
  end

  # Memoize the viewing user
  def viewer
    @viewer ||= User.find @viewerid
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
      self.partition ||= Partition.new([0, scope_count ], max_window_size)
      false
    elsif cache
      true
    else
      # Convert the itemscope relation into a hash on entity types
      counts = Counts.new
      @querytags.each { |tag| count_tag tag, counts }

      # Sort the scope by number of hits, descending
      self.cache = counts.itemstubs
      bounds = (0...(@querytags.count)).to_a.map { |i| (@querytags.count-i)*100 } # Partition according to the # of matches
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

  def sort_table_name
    result_type.table_name
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
      entries = modelname.constantize.where(id: records[modelname]).to_a

      # Restore the ordering after randomizing by
      entry_map = entries.map &:id
      records[modelname] = records[modelname].collect { |id| entries[entry_map.index id] }
    }

    # Finally convert the original, ordered array of item specs to the corresponding array of records (also ordered)
    cache_slice.collect { |itemspec|
      modelname= itemspec.split('/').first
      records[modelname].shift
    }
  end

  def max_window_size
    5
  end

  # Return the existing partition, if any; otherwise, create one otherwise
  def safe_partition
    if pt = partition
      pt
    else
      self.partition = Partition.new [0, full_size], max_window_size
    end
  end

  private

  ######## The setters for instance variables are private to prevent them being set after initialization

  # Convert the querytags string parameter into an array of tags for internal use.
  # When querytags are given as strings (as opposed to tag ids), they are stored
  # temporarily in the session with negative ids, for use in later callbacks.
  def querytags= querytext
    @querytags ||=
        if querytext
          tags_cache ||= TagsCache.find_or_initialize_by session_id: session_id
          special = tags_cache.tags || {}
          qt =
              querytext.split(",").collect do |e|
                e.strip!
                if (e=~/^\d*$/) # numbers (sans quotes) represent existing tags that the user selected
                  Tag.find e.to_i
                elsif e=~/^-\d*$/ # negative numbers (sans quotes) represent special tags from before
                  # Re-save this one
                  tag = Tag.new name: special[e]
                  tag.id = e.to_i
                  tag
                else
                  # This is a new special tag. Unless it matches an existing tag, convert it to an internal tag and add it to the cache
                  name = e.gsub(/\'/, '').strip
                  unless tag = Tag.strmatch(name, { matchall: true, uid: @userid }).first
                    tag = Tag.new name: name
                    unless special.find { |k, v| (special[k] = v and tag.id = k.to_i) if v == name }
                      tag.id = -1
                      # Search for an unused id
                      while special[tag.id.to_s] do
                        tag.id = tag.id - 1
                      end
                      special[tag.id.to_s] = tag.name
                    end
                  end
                  tag
                end
              end
          tags_cache.tags = special
          tags_cache.save
          qt
        else
          []
        end
  end

  def entity_id= i
    @entity_id = i.to_i
  end

  def viewerid= id
    @viewerid = id.to_i
  end

  def org= o
    @org = o.to_sym
  end

end

class SearchIndexCache < ResultsCache
  include ResultTyping
  include EntitiesCache

  def stream_id
    'search'
  end

  def ordereditemscope
    # Use the org parameter and the ASC/DESC attribute to assert an ordering
    if org == :viewed
      uniqueitemscope.select("#{result_type.table_name}.*, max(rcprefs.updated_at)").joins(:toucher_pointers).group("#{result_type.table_name}.id").order('max("rcprefs"."updated_at") DESC')
    end || super
  end

end

# Cache for facets of a user's collection, in fact just a stub for selecting other classes
class UsersShowCache < ResultsCache
  include ResultTyping

  # Different subclasses are used to handle different result types
  def self.subclass_for result_type=nil
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

class UsersAssociatedCache < UsersShowCache

end

class UsersCollectionCache < UsersShowCache
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
    if @org && (@org.to_sym == :updated)
      uniqueitemscope.joins(:feeds).order('"feeds"."last_post_date"' + (@sort_direction || 'DESC'))
    else
      super
    end
  end

end

class SitesFeedsCache < ResultsCache
  include EntitiesCache

  def site
    @site ||= Site.find @entity_id
  end

  def itemscope
    site.feeds
  end
end

class SitesRecipesCache < ResultsCache
  include EntitiesCache

  def site
    @site ||= Site.find @entity_id
  end

  def itemscope
    sitepath = site.home.sub /^https?:\/\//, ''
    Recipe.joins(:page_refs).where('"page_refs"."domain" LIKE ?', "%#{sitepath}%")
  end
end

# Provide the set of lists the user has collected, but only those visible to her
class UserCollectedListsCache < ResultsCache
  include UserFunc
  include EntitiesCache

  def itemscope
    @itemscope ||= user.decorate.collected_lists(viewer) # ListServices.lists_collected_by user, viewer
  end
end

# Provide the set of lists the user owns
class UserOwnedListsCache < ResultsCache
  include UserFunc
  include EntitiesCache

  def itemscope
    @itemscope ||= user.decorate.owned_lists viewer # ListServices.lists_owned_by user, viewer
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
        user.decorate.owned_lists viewer # ListServices.lists_owned_by user, viewer
      when 'collected'
        user.decorate.collection_lists viewer # ListServices.lists_collected_by user, viewer
      when 'all'
        List.unscoped
      else # By default, we only see lists belonging to our friends and Super that are not private, and all those that are public
        ListServices.visible_lists( viewer, true).where.not(name_tag_id: [16310,16311,16312]).order(owner_id: :desc)
    end
  end
end

class RecipesAssociatedCache < ResultsCache
  def recipe
    @recipe ||= Recipe.find @entity_id
  end
end

# list's content visible to current user (ListStreamer)
class ListsShowCache < ResultsCache
  include TaggingCache

  def list
    @list ||= List.find @entity_id
  end

  # The itemscope is the initial query for all possible items, subject to subqueries via count_tag
  def itemscope
    @itemscope ||= ListServices.new(list).tagging_scope @viewerid
  end

  def stream_id
    "list_#{@entity_id}_contents"
  end

end

class ListsContentsCache < ListsShowCache

end

class ListsAssociatedCache < ListsShowCache

end

# list of feeds
class FeedsIndexCache < ResultsCache
  include EntitiesCache

  # Declare a different default org
  def self.params_needed
    super + [ [:org, :newest] ]
  end

  def max_window_size
    10
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
      when :updated
        uniqueitemscope.order('"feeds"."last_post_date" ' + (@sort_direction || 'DESC'))
      when :approved
        uniqueitemscope.order('"feeds"."approved" ' + (@sort_direction || 'ASC'))
      else
        super
    end
  end

end

# list of feed items
class FeedsShowCache < ResultsCache
  include EntitiesCache

  def feed
    @feed ||= Feed.find @entity_id
  end

  def itemscope
    @itemscope ||= feed.feed_entries
  end

end

class FeedsAssociatedCache < FeedsShowCache

end

class FeedsContentsCache < FeedsShowCache

end

# users: list of users visible to current_user (UsersStreamer)
class UsersIndexCache < ResultsCache
  include EntitiesCache

  def max_window_size
    10
  end

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

  def sort_table_name
    'user_relations'
  end

end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache
  include EntitiesCache
  include UserFunc

  def itemscope
    @itemscope ||= user.decorate.owned_lists viewer
  end

end

class TagsIndexCache < ResultsCache
  include EntitiesCache

  def max_window_size
    10
  end

  def self.params_needed
    super + [:tagtype, :batch]
  end

  # Tags don't go through Taggings, so we just use/count them directly
  def count_tag tag, counts
    super # Do the usual strscopes thing
    counts.incr_by_scope itemscope.where(normalized_name: tag.normalized_name || Tag.normalizeName(tag.name)), 10
  end

  def itemscope
    return @itemscope if @itemscope
    @itemscope = @tagtype ? Tag.where(tagtype: @tagtype) : Tag.unscoped
    if @batch
      first = (@batch.to_i-1) * 100
      @itemscope = @itemscope.order(id: :ASC).where("id >= #{first} and id < #{first+100}")
    end
    @itemscope
  end

end

class TagsAssociatedCache < ResultsCache
  include TaggingCache

  def tag
    @tag ||= Tag.find @entity_id
  end

  def itemscope
    @itemscope ||= tag.taggings
  end

end

class SitesIndexCache < ResultsCache
  include EntitiesCache

  def self.params_needed
    super + [:approved]
  end

=begin
  def max_window_size
    10
  end
=end
  def approved
    if defined?(@approved)
      case @approved
        when 'invisible'
          [ nil, false ]
        when 'true'
          true
        when 'false'
          false
        when '', 'nil'
          nil
      end
    else
      true
    end
  end

  def itemscope
    @itemscope ||= Site.where(approved: approved)
  end

end

class SitesShowCache < ResultsCache
  include ResultTyping
  include EntitiesCache

  def site
    @site = Site.find @entity_id
  end

  def itemscope
    @itemscope ||= site.contents_scope result_type.model_class
  end
end

class SitesAssociatedCache < SitesShowCache

end

class ReferencesIndexCache < ResultsCache
  include EntitiesCache

  def max_window_size
    10
  end

  def self.params_needed
    super + [:type]
  end

  def type
    @type ||= 0
  end

  def typeclass
    'ImageReference' # Reference.type_to_class(type).to_s
  end

  def itemscope
    @itemscope ||= (typeclass == Reference) ? Reference.unscoped : Reference.where(type: typeclass)
  end

end

class ReferenceCache < ResultsCache

  def reference
    @reference ||= Reference.find @entity_id
  end

end

class ReferentsIndexCache < ResultsCache
  include EntitiesCache

  def max_window_size
    10
  end

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
