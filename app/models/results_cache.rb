require './lib/querytags.rb'
require 'rcpref.rb'
require 'tagging.rb'
require 'result_type.rb'

# Object to put a uniform interface on a set of results, whether they
# exist as a scope (if there is no search) or an array of Rcprefs (with search).
# Format of the hash:
# -- keys are class/id pairs, for accumulating references
# -- values are either: an integers (for weighting the results by appearances) or a sort key
# Parameters:
# -- key_or_keys can be:
#    ** an ActiveRecord::Relation from which ids and (possibly) sort keys can be extracted
#    ** a string, for use directly as a key
#    ** an ApplicationRecord model
#    ** an array of any of the above
# -- pluck_key_or_increment can be:
#    ** an integer, in which case values will be accumulated additively for sorting
#    ** a specifier (either symbol or array), suitable for passing to ActiveRecord::Relation#pluck, for getting the sort value
#    ** any other type of value, which is asserted directly as the sort key
# -- accumulate is a flag for disambiguating an incr that can be added from one that is just asserted
class Counts < Hash
  def include key_or_keys, pluck_key_or_increment=1, accumulate=true
    case key_or_keys
      when ActiveRecord::Relation
        # Late-breaking conversion of scope into items
        modelname = key_or_keys.model.to_s
        NestedBenchmark.measure "Counted #{modelname}s" do
          if pluck_key_or_increment.is_a?(Integer)
            # We are accumulating hits, weighted by pluck_key_or_increment
            key_or_keys.pluck(:id).uniq.each do |id|
              key = modelname+'/'+id.to_s
              self[key] += pluck_key_or_increment
            end
          else
            # We are accumulating hits, using as values what we will later sort by
            pluck_key_or_increment = Arel.sql pluck_key_or_increment
            to_pluck = [ :id, pluck_key_or_increment].compact
            key_or_keys.pluck(*to_pluck).uniq.each do |idval| # #pluck provides an array of results per record
              id, sortval = idval
              self[modelname+'/'+id.to_s] = sortval || 1
            end
          end
        end
      when Array
        NestedBenchmark.measure "Counted ids" do
          key_or_keys.each { |k| self.include k, pluck_key_or_increment }
        end
      when String
        if pluck_key_or_increment.is_a?(Integer) && accumulate
          self[key_or_keys] += pluck_key_or_increment
        else
          self[key_or_keys] = pluck_key_or_increment
        end
      when ApplicationRecord
        key = "#{key_or_keys.model_name.name}/#{key_or_keys.id}"
        if pluck_key_or_increment.is_a?(Integer) && accumulate
          self[key_or_keys] += pluck_key_or_increment
        else
          self[key_or_keys] = pluck_key_or_increment
        end
    end
    self # ...for chainability
  end

  def [](ix)
    super(ix) || 0
  end

  # Define an array of itemstubs: strings denoting entity type/value pairs
  def itemstubs sorted=true
    # Sort the count keys in descending order of hits
    @itemstubs ||= sorted ? self.keys.sort { |k1, k2|
      self[k2] <=> self[k1]
    } : self.keys
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

  def merge_counts extant_counts
    # Two cases:
    #  -- there's an existing set of counts => merge counts in an exclusive fashion
    #  -- no counts exist yet => return unchanged
    if extant_counts
      newcounts = collect { |key, value|
        if extant_counts.has_key? key
          value += extant_counts[key] unless value.is_a?(Time)
          [key, value]
        end
      }.compact
      Counts[newcounts]
    else
      self
    end

  end

end

# A partition is an array of offsets within another array or a scope, denoting the boundaries of groups
# for streaming.
class Partition < Array
  attr_accessor :cur_position, :window, :max_window_size

  def initialize range, mws=max_window_size
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
      lb..ub # if ub > lb
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

  def done!
    while self[-1] > cur_position
      self.pop
    end
    self.push cur_position
    window = self.window.min..cur_position
  end

  def done? # public
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
    (self.find_index { |lower_bound| lower_bound > ix } - 1) unless (ix < self[0]) or (ix >= self[-1])
  end

end

# Repository for org options on ResultsCaches
class OrgOptions < Array
  require 'type_map.rb'

  @org_types = TypeMap.new(
           none: ['none', 0],
           viewed: ['RECENTLY VIEWED', 1],
           newest: ['NEWEST', 2],
           updated: ['REVISED AT', 3],
           ratings: ['RATINGS', 4],
           popularity: ['POPULARITY', 5],
           random: ['RANDOM', 6],
           approved: ['APPROVED', 7],
           referent_id: ['REFERENT', 8],
           recipe_count: ['#RECIPES', 9],
           feed_count: ['#FEEDS', 10],
           definition_count: ['#DEFINITIONS', 11],
           posted: ['LATEST POST', 12],
           alphabetic: ['NAME', 13],
           activity: ['ACTIVITY', 14],
           meaningless: ['MEANINGLESS', 15],
           hotness: [ 'HOTNESS', 16 ]
  )

  def self.lookup val
    symval = @org_types.sym val
    raise "Invalid type #{val}" if symval == :none
    symval
  end

  def initialize keys
    # Check args against valid options
    keys.each { |key|
      self.push(self.class.lookup key) if key
    }
  end

  # Is the given value among the allowed values?
  def valid? val
    self.include? @org_types.sym(val)
  end

  # For a valid org choice, provide a human-friendly label
  def label orgval
    I18n.t 'results_cache.org_button_label.' + orgval.to_s
  end

end

# A mixin for ResultsCaches responding to the User controller
module UserFunc

  def user
    @user ||= User.find @entity_id
  end

end

# Prototype of definitions and methods for searching to a ResultsCache. These are stubs which either define defaults
# or do nothing
module DefaultSearch

  def stream_id # public
    "#{self.class.to_s}-#{@entity_id}"
  end

  # Every meaningful ResultsCache MUST define an itemscope for the base set of results
  # Return a scope or array for the entire collection of items
  def itemscope
    raise 'Abstract Method itemscope'
  end

  def itemscopes
    [itemscope]
  end

  # Provide an array consisting of
  #  -- a scope for fetching ordered items,
  #  -- a key suitable for passing to .order()
  #  -- (optionally) a key for fetching the sort value from the scope (without ordering)
  # USES @org parameter, which indicates how to sort the iscope relation
  def orderingscope iscope=itemscope
    [ iscope ] +
    case org
      when :newest
        ['created_at DESC', 'created_at']
      when :updated
        ['updated_at DESC', 'updated_at']
      else # :ratings, :popularity, :random, :viewed, :approved, :referent_id, :recipe_count, :feed_count, :definition_count
        [ ]
    end
  end

  # This is the end of the superclass hierarchy for counting a tag, so we return the unmodified counts
  def count_tag tag, counts, iscope
    counts
  end

  # When taking a slice out of the (singular) itemscope, load the associated entities meanwhile
  # NB This is not valid when the cache uses multiple scopes--but that should be handled by cache_and_partition
  def scope_slice offset, limit
    iscope = itemscope
    oscope, sort_key = orderingscope iscope
    oscope = oscope.order sort_key if sort_key
    oscope = oscope.includes(:entity) if %w{ rcprefs taggings }.include? iscope.model_name.collection
    # oscope = oscope.includes(:rcprefs) if iscope.model.is_a?(Collectible)
    oscope = oscope.including_user_pointer(viewer_id) if iscope.model.is_a?(Collectible)
    oscope.offset(offset).limit(limit).to_a
  end

end

# ...for a ResultsCache based on a table of a particular model, which presumably has scope for string searching
module ModelSearch

  # This is a prototypical count_tag method, which digests the itemscope in light of a tag,
  # incrementing the counts appropriately
  def count_tag tag, counts, iscope
    tagname = tag.normalized_name.if_present || Tag.normalize_name(tag.name)
    iscope, sort_key, pluck_key = orderingscope iscope
    pluck_key ||= sort_key
    model = iscope.model
    if model.respond_to? :strscopes
      NestedBenchmark.measure 'Fuzzy searches on entity e.g., title and description' do
        strscopes = model.strscopes "%#{tag.name}%" do |joinspec=nil|
          joinspec ? iscope.joins(joinspec) : iscope
        end
        counts.include strscopes, pluck_key
      end
      NestedBenchmark.measure 'Exact searches on entity e.g., title and description' do
        strscopes = model.strscopes tag.name do |joinspec=nil|
          joinspec ? iscope.joins(joinspec) : iscope
        end
        counts.include strscopes, pluck_key
      end
    end
    super
  end

end

# Defines search for Collectible entities, i.e. looking for comments that match a tag
module CollectibleSearch

  # What to sort on AND what to pass to #pluck for manual sorting
  def orderingscope iscope = itemscope
    case org
    when :viewed
      return [iscope, '"rcprefs"."updated_at" DESC', '"rcprefs"."updated_at"']
    when :newest
      return [iscope, '"rcprefs"."created_at" DESC', '"rcprefs"."created_at"']
    else
      return super
    end
  end

  def count_tag tag, counts, iscope
    tagname = tag.normalized_name || Tag.normalize_name(tag.name)
    iscope, sort_key, pluck_key = orderingscope iscope
    counts.include iscope.matching_comment(tagname), (pluck_key || sort_key)
    super
  end
end

module TaggableSearch

  # module Uniquify
  # Allowing for the possibility of redundant items that are nonetheless significant for searching,
  # the redundant itemscope may need to be retained (e.g., in the case of searching tagging-based scopes)
  # while the final presentation (and initial count) are without redundancy.
  # NB This happens to work for both collections (based on Rcpref) and taggings b/c both have
  # polymorphic 'entity' associations

  # Filter an entity scope by tag contents
  def count_tag tag, counts, iscope
    tagname = tag.name
    iscope, sort_key, pluck_key = orderingscope iscope
    pluck_key ||= sort_key
    model = iscope.model
    NestedBenchmark.measure 'via taggings (with synonoms)' do
      # We index using tags, for taggable models
      if model.reflect_on_association :tags # model has :tags association
        # Search by fuzzy string match
        counts.include iscope.joins(:tags).merge(Tag.by_string(tagname)), pluck_key # One point for matching in one field

        # Search across synonyms
        counts.include iscope.joins(:tags).merge(Tag.synonyms_by_str(tagname)), pluck_key # One point for matching in one field

        # Search for exact name match
        counts.include iscope.joins(:tags).merge(Tag.by_string(tagname, true)), pluck_key # Extra points for exact name match
      end
    end
    super
  end
end

# Search for tags, typically for TagsController#index
module TagSearch
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def params_needed
      super + [:tagtype, :batch]
    end

  end

  # Tags don't go through Taggings, so we just use/count them directly
  def count_tag tag, counts, iscope
    nname = tag.normalized_name || Tag.normalize_name(tag.name)
    iscope, sort_key, pluck_key = orderingscope iscope
    pluck_key ||= sort_key
    counts.include iscope.where('normalized_name LIKE ?', "%#{nname}%"), pluck_key
    counts.include iscope.where(normalized_name: nname), pluck_key
    super
  end

  # When taking a slice out of the (single) itemscope, load the associated entities meanwhile
  # NB This is not valid when the cache uses multiple scopes--but that should be handled by cache_and_partition
  def scope_slice offset, limit
    offset += (@batch.to_i-1) * 100 if @batch
    super
  end

  def itemscope
    @itemscope ||= @tagtype ? Tag.of_type(@tagtype) : Tag.all
  end

  def orderingscope iscope=itemscope
    case org
      when :popularity
        [ iscope.joins(:taggings).group('tags.id'), 'count(tags.id)' ]
      when :meaningless
        [ iscope.meaningless ]
      else
        super
    end
  end

end

# Methods and defaults for a ResultsCache based on a user's collection
# @entity_id parameter denotes the user
# NB: unlike most searches, a CollectionCache can be across several entity types.
# Specifically, the Cookmarks subcollection picks up all collectible entities except
# friends, lists and feeds
module CollectionCache
  include ModelSearch # Search via strscopes on the specific model
  include TaggableSearch # Search via taggings
  include CollectibleSearch # Search via Rcprefs (look at the user's comments)
  include UserFunc
  include ResultTyping

  # The itemscope is one or more scopes on the relevant models
  def itemscopes
    # :entity_type => %w{ Recipe Site FeedEntry }, Feed
    @itemscopes ||= [result_type.entity_params[:entity_type]].flatten.collect { |entity_type|
      entity_type.constantize.collected_by_user @entity_id, viewer_id
    }.compact
  end

  def itemscope
    @itemscope ||=
        if itemscopes.count == 1
          itemscopes.first
        else
          raise 'Called itemscope on non-singular CollectionCache model'
        end
  end

  protected

end

module ExtractParams
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def extract_params params_hash={}
      # Since params_needed may be key/default pairs as well as a list of names
      defaulted_params = ActiveSupport::HashWithIndifferentAccess.new
      paramlist = self.params_needed.collect { |pspec|
        if pspec.is_a? Array
          defaulted_params[pspec.first] = pspec.last.to_s # They're recorded as strings, since that's what params_hash use
          pspec.first
        else
          pspec
        end
      }.uniq

      # The entity_id comes in the :id param, but this can cause confusion with the AR id for the record.
      # Consequently, we use :entity_id internally
      defaulted_params[:entity_id] = params_hash[:id] if params_hash[:id]

      # relevant_params are the parameters that will bust the cache when changed from one request to another
      defaulted_params.merge(params_hash).slice *paramlist
    end
  end
  
  # Whenever the params get assigned--whether directly by assignment, by mass-assignment, or by fetching records--we
  # copy the param values into the cache object

  # Do type conversions when accepting instance variables
  def params= params_hash
    defined?(super) ? super : (@params = params_hash.clone) # To handle, e.g., serialization
    params_hash.each { |key, val|
      setter = :"#{key}="
      if self.private_methods.include? setter
        self.send setter, val
      else
        self.instance_variable_set "@#{key}".to_sym, val
      end
    }
  end

end

# A DefaultSearch is a shell for handling the case where there ARE no results to manage (eg., in a #show action)
class NullResults
  include DefaultSearch
  include ExtractParams

  attr_reader :params, :admin_view, :querytags, :org

  # Declare the parameters needed for this class
  def self.params_needed
    # [:entity_id, :viewer_id, :admin_view, :querytags, [:org, :newest], :sort_direction, [ :result_type, '' ] ]
    [:admin_view, [:org, :newest]]
  end

  def initialize params_hash={}
    self.send :'params=', self.class.extract_params(params_hash)
    # We blow off any querytags, but respond with an empty array
    @querytags = []
  end

  def has_query? # public
    false
  end

  # Every meaningful ResultsCache MUST define an itemscope for the base set of results
  # Return a scope or array for the entire collection of items
  def itemscope
    raise 'Abstract Method itemscope' #  needs to be overridden
  end

end

class ResultsCache < ApplicationRecord
  include ActiveRecord::Sanitization
  include DefaultSearch # Defaults for *Cache methods
  include ExtractParams

  before_save do
    session_id != nil
  end

  belongs_to :tags_cache, :foreign_key => :session_id

  # The user is whom the results were generated for (respecting views)
  belongs_to :viewer, :foreign_key => :viewer_id, :class_name => 'User'

  # The ResultsCache class responds to a query with a series of items.
  # As a model, it saves intermediate results to the database

  # Standard parameters
  attr_reader :entity_id, :admin_view, :querytags, :org, :sort_direction

  attr_accessor :typeset, :itemscope
  # attr_reader :result_type
  serialize :params
  serialize :cache
  serialize :partition
  attr_accessor :items
  delegate :window, :next_index, :'done!', :'done?', :max_window_size, :to => :safe_partition

  def self.mass_assignable_attributes
    [ :params ]
  end

  # What to present as choices for sorting the results
  def org_options
    @org_options ||= OrgOptions.new supported_org_options
  end

  # We wrap the result_type string attribute in a ResultType class that provides more functionality
  def result_type
    @result_type ||= ResultType.new read_attribute(:result_type)
  end

  # Assert an organization scheme, which must be among those declared in #supported_org_options
  def org= orgscheme
     @org = orgscheme if org_options.valid?(orgscheme)
  end

  # Default the organization scheme to the first available option (if any)
  def org
    @org ||= org_options.first
  end

  # Get the current results cache and return it if relevant. Otherwise,
  # create a new one
  def self.retrieve_or_build session_id, result_types, viewer, params_hash={}
    # Derive the subclass of ResultsCache that will handle generating items
    caching_class = self
    if (self == ResultsCache) && params_hash['controller'].present? && params_hash['action'].present?
      classname = params_hash['controller'].camelize + params_hash['action'].capitalize + 'Cache'
      unless caching_class = (classname.constantize rescue nil)
        logger.debug 'No ResultsCache handler ' + classname
        return []
      end
    end
    result_types.collect { |result_type|
      # The choice of handling class, and thus the cache, is a function of the result type required as well as the controller/action pair
      # Give the class a chance to defer to a subclass based on the result type
      cc = caching_class.respond_to?(:subclass_for) ? caching_class.subclass_for(result_type) : caching_class
      rc_params = cc.extract_params params_hash
      # We SEARCH on the rc_attribs. The rest of the parameters are stored in the model's params.
      # The difference is that the cache gets busted if the params change
      # rc = cc.find_by(rc_attribs) || cc.new(rc_attribs)
      rc = cc.create_with(params: rc_params).
          find_or_initialize_by session_id: session_id,
                                result_type: result_type, # params_hash[:result_type],
                                viewer: viewer

      # For purposes of busting the cache, we assume that sort direction is irrelevant
      # NB: At the point, the params_hash in rc are in exactly the same form as the query params_hash, i.e. strings
      if rc.id && (rc.params == rc_params) # TODO: Take :nocache into consideration
        logger.debug "Found applicable #{cc} for #{rc.result_type.class} '#{rc.result_type}'"
      else # Bust the cache if the prior params don't match the new ones
        diffs = (rc.params.keys | rc_params.keys).collect {|key|
          "#{key}: #{rc.params[key] || nil}=>#{rc_params[key] || nil}" if rc.params[key] != rc_params[key]
        }.compact.join('; ') if rc.params.present?
        diffs = diffs ? "; busted cache on #{diffs}" : '. (new)'

        rc.cache = rc.partition = rc.items = nil
        logger.debug "Started #{cc} for #{rc.result_type.class} #{rc.result_type}#{diffs || '.'}"
      end
      # Assign the params hash--whether it will change or not--to side-effectively set instance variables
      rc.send :'params=', rc_params
      rc
    }.compact
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
    # The limit isn't specified iff this is the first window of results: our signal to bust the cache
    # TODO: develop a better cache expiration strategy
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

  # Take a window of entities from the scope or the results cache
  def items # public
    @items ||=
        if cache_and_partition
          slice_cache
          # elsif itemscope.is_a? Array
          #   itemscope.slice safe_partition.window.min, safe_partition.windowsize
        else
          scope_slice safe_partition.window.min, safe_partition.windowsize
        end
  end

  # Return the next item in the current window, incrementing the cur_position
  def next_item # public
    if items
      if i = safe_partition.next_index
        done! unless @items[i] # i is relative to the current window
        @items[i]
      end
    end
  end

  def has_query? # public
    (@querytags ||= []).count > 0
  end

  def ready? # Have the items been sorted out yet?  public
    ((@querytags ||= []).count == 0) || cache
  end

  def nmatches # Force the partition and report the first window  (public)
    cache_and_partition
    partition[1]
  end

  # Return the total number of items in the result. This doesn't have to be every possible item, just
  # enough to stay ahead of the window.
  def full_size # public
    return partition[-1] if partition # Don't create if doesn't exist
    return cache.count if cache
    begin
      scope_count
    rescue Exception => e
      1000000
    end
  end

  # Report a previously-saved parameter (or, in fact, any instance variable)
  def param sym # public (used in testing)
    self.instance_variable_get "@#{sym}".to_sym
  end

  protected

  def supported_org_options
    [ :viewed, :newest ]
  end

  # Count the number of items in the basic scope in a smart way
  def scope_count
    if cache
      return cache.count
    else
      itemscopes.inject(0) do |memo, iscope|
        # To avoid loading the relation, we construct a count query from the scope query
        scope_query = iscope.to_sql
        sql = %Q{ SELECT COUNT(*) from (#{scope_query}) as internalQuery }
        res = ActiveRecord::Base.connection.execute sql
        memo + res.first["count"].to_i
      end
    end
  end

  # Convert the scope to a cache of entries, as needed. Two cases:
  # 1) The data can be provided by a single query => set up a partitioning object and use that to reference
  #   elements of the query
  # 2) The data needs to be cached en masses => it is stored in a list of strings denoting the entity type
  #   and ID for each relevant entity.
  def cache_and_partition
    # count_tag is the hook for applying a tag to the current counts
    return (cache != nil) unless self.respond_to? :count_tag
    if partition_on_scope?
      # Straight passthrough of the itemscope => no cache required
      self.partition ||= Partition.new([0, scope_count], max_window_size)
      false
    elsif cache
      true
    else
      # We're here EITHER because there are querytags (which in general necessitate multiple queries)
      # OR the 'scope' really requires multiple queries (say, on different entity types)
      # Either way, we need to produce a cache as output
      counts =
          if @querytags.present?
            # Convert the itemscope relation into a hash on entity type/id pairs
            @querytags.inject(nil) { |memo, tag|
              if memo && memo.empty?
                memo
              else
                merge_counts memo, itemscopes.inject(Counts.new) { |cmemo, iscope| count_tag tag, cmemo, iscope }
              end
            }
          else # By the logic of partition_on_scope?, we must have multiple scopes to merge in the cache
            itemscopes.inject(Counts.new) do |memo, iscope|
              # Get the ordering scope, together with a sorting key and a pluck key
              iscope, sort_key, pluck_key = orderingscope iscope
              memo.include iscope, (pluck_key || sort_key) # ...and there must be a sort key to pluck and use
            end
          end
      self.cache = counts.itemstubs
      self.partition = Partition.new([0, cache.count], max_window_size)      # bounds = (0...(@querytags.count)).to_a.map { |i| (@querytags.count-i)*100 } # Partition according to the # of matches
      wdw = partition.window
      # self.partition = counts.partition bounds
      self.window = [wdw.min, wdw.max]
      true
    end
  end

  # Can the entities be presented as a partition on a single scope?
  # ...not if there are querytags (which entail multiple queries)
  # ...and not if there are multiple scopes (only an issue in subclasses)
  def partition_on_scope?
    singular_scope = itemscopes.count <= 1
    notags = (@querytags ||= []).count == 0
    notags && singular_scope
  end

  # Incorporate the counts from a tag into existing counts, if any
  def merge_counts prior_counts, new_counts
    prior_counts ?
        NestedBenchmark.measure('merge_counts') { new_counts.merge_counts prior_counts } :
        new_counts
  end

  # Declare the parameters needed for this class
  def self.params_needed
    [:entity_id, :admin_view, :querytags, :org, :sort_direction ]
  end

  # Convert from item stubs (modelname + id) to entities, in the most efficient manner possible
  def slice_cache
    if cache_slice = cache.slice(safe_partition.window.min, safe_partition.windowsize)

      # First, create a hash of arrays, indexed by modelname, to collect the ids for that model
      records = {}
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
  end

  def max_window_size
    5
  end

  # Return the existing partition, if any; otherwise, create one
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
                  unless tag = Tag.strmatch(name, {matchall: true, uid: @userid}).first
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

  def org= o
    @org = o.to_sym
  end

end

class SearchIndexCache < ResultsCache
  include ResultTyping
  include ModelSearch
  include TaggableSearch

  def stream_id # public
    'search'
  end

  def orderingscope iscope=itemscope
    # Eliminate empty lists
    iscope = iscope.where.not(name_tag_id: [16310, 16311, 16312]) if result_type == 'lists'
    # Use the org parameter and the ASC/DESC attribute to assert an ordering
    case org
      when :viewed
        [ iscope.
            select("#{result_type.table_name}.*, max(rcprefs.updated_at)").
            joins(:toucher_pointers).
            group("#{result_type.table_name}.id"),
          'max("rcprefs"."updated_at")' ]
      else
        super iscope
    end
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

  protected

  def supported_org_options
    [ :viewed, :newest ]
  end

  # The module defines the default itemscope on a user's collection,
  # appropriately using the result_type parameter
end

# user's collection visible to current_user (UserCollectionStreamer)
class UsersRecentCache < UsersCollectionCache

end

# user's collection visible to viewer (UserCollectionStreamer)
class UsersBiglistCache < UsersCollectionCache

  def itemscope
    @itemscope ||=
        Rcpref.where('private = false OR "rcprefs"."user_id" = ?', viewer_id).
            where.not(entity_type: %w{ Feed User List})
  end
end

class UserFeedsCache < UsersCollectionCache

  def self.params_needed
    super + [ [:org, :posted] ]
  end

  def orderingscope iscope=itemscope
    case org
      when :posted
        [ iscope, 'last_post_date DESC', 'last_post_date' ]
      else
        super
    end
  end

  def itemscope
    # If we're looking at the feeds with the latest post, ignore those
    # with no posts, which would otherwise come up first
    scope = Feed.collected_by_user @entity_id, viewer_id
    org == :posted ? scope.where.not(last_post_date: nil) : scope
  end

  protected

  def supported_org_options
    [ :posted, :newest ]
  end

end

class SitesFeedsCache < ResultsCache
  include ModelSearch

  def site
    @site ||= Site.find @entity_id
  end

  def itemscope
    site.feeds
  end
end

class SitesRecipesCache < ResultsCache
  include ModelSearch

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
  include ModelSearch

  def itemscope
    @itemscope ||= user.decorate.collected_lists(viewer)
  end
end

# Provide the set of lists the user owns
class UserOwnedListsCache < ResultsCache
  include UserFunc
  include ModelSearch
  include CollectibleSearch

  def orderingscope iscope = itemscope
    @org == :newest ? [ iscope, 'created_at DESC', 'created_at' ] : super
  end

  def itemscope
    unless @itemscope
      @itemscope = user.decorate.owned_lists viewer
      @itemscope = @itemscope.viewed_by_user(@entity_id, viewer_id) if @org == :viewed
    end
    @itemscope
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
  include ModelSearch

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
            ListServices.visible_lists(viewer, true).where.not(name_tag_id: [16310, 16311, 16312]) # .order(owner_id: :desc)
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
  include TaggableSearch
  include ModelSearch
  include CollectibleSearch

  attr_accessor :list_services

  def list
    @list ||= List.find @entity_id
  end

  def list_services
    @list_services ||= ListServices.new list
  end

  def itemscopes
    # Create a scope for each type of object collected
    return @itemscopes if @itemscopes
=begin
        NestedBenchmark.measure "Counted ListsShowCache#itemscopes via :pluck" do
          itemscope.pluck(:entity_type, :entity_id).inject(Hash.new) { |memo, pair|
            memo[pair.first] = (memo[pair.first] ||= []) << pair.last
            memo
          }.collect { |entity, ids|
            entity.constantize.where(id: ids)
          }
        end
=end
    @itemscopes =
    NestedBenchmark.measure "Counted ListsShowCache#itemscopes by entity type and id" do
      itemscope.group(:entity_type).pluck(:entity_type).collect do |type|
        list_services.entity_scope type, viewer
      end
    end
  end

  # TODO: offer option of ordering by list order
  def orderingscope iscope=itemscope
        case org
          when :newest
            # Newest in the list
            [ iscope, 'taggings.created_at DESC', 'taggings.created_at' ]
          else
            super
        end
  end

  # The itemscope is the initial query for all possible items
  def itemscope
    @itemscope ||= list_services.tagging_query viewer_id
  end

  def stream_id # public
    "list_#{@entity_id}_contents"
  end

  protected

  def supported_org_options
    [ ]
  end

end

class ListsContentsCache < ListsShowCache

end

class ListsAssociatedCache < ListsShowCache

end

# list of feeds
class FeedsIndexCache < ResultsCache
  include ModelSearch

  # Declare a different default org
  def self.params_needed
    super + [:approved]
  end

  def max_window_size
    10
  end

  def approved
    if defined?(@approved)
      case @approved
        when 'invisible'
          [nil, false]
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
    @itemscope ||=
        case result_type.subtype
          when 'collected' # Feeds actually collected by user and friends
            persons_of_interest = [viewer_id, 1, 3, 5].map(&:to_s).join(',')
            Feed.joins(:collector_pointers).
                where("rcprefs.user_id in (#{persons_of_interest})").
                order("rcprefs.user_id DESC").# User's own feeds first
            order("rcprefs.updated_at DESC") # Most recent first (within user)
          when 'all' # For admins only: every feed in the world
            Feed.order 'approved DESC'
          when 'approved' # Default: normal user view for shopping for feeds (only approved feeds)
            Feed.where approved: true
          else
            Feed.unscoped  # where approved: (admin_view ? approved : true)
        end
  end

  def orderingscope iscope = itemscope
    case org # Blithely assuming a singular itemscope
    when :hotness
      [ iscope, '"feeds"."hotness" DESC', '"feeds"."hotness"']
    when :posted
      [ iscope.where.not(last_post_date: nil), '"feeds"."last_post_date" DESC', '"feeds"."last_post_date"']
    when :approved
      [ iscope, '"feeds"."approved" DESC', 1  ]
    else
      super
    end
  end

  protected

  def supported_org_options
    [ :hotness, :posted, :newest, (:approved if admin_view) ].compact
  end

end

# list of feed items
class FeedsShowCache < ResultsCache
  include ModelSearch
  include CollectibleSearch

  def feed
    @feed ||= Feed.find @entity_id
  end

  def orderingscope iscope=itemscope
    case org
      when :newest
        # Newest entries
        [iscope, '"feed_entries"."published_at" DESC', '"feed_entries"."published_at"']
      when :viewed
        [ iscope.joins(:toucher_pointers), 'rcprefs.updated_at' ]
      else
        super
    end
  end

  def itemscope
    @itemscope ||= feed.feed_entries
  end

  def supported_org_options
    [ :newest ]
  end

end

class FeedsAssociatedCache < FeedsShowCache

end

class FeedsContentsCache < FeedsShowCache

end

# users: list of users visible to current_user (UsersStreamer)
class UsersIndexCache < ResultsCache
  include ModelSearch

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
                  where.not(id: viewer.followee_ids+[viewer_id, 4, 5]).
                  order('count_of_collecteds DESC')
            else
              User.where(private: false).where.not(id: [4, 5])
          end
        end
  end

  def orderingscope iscope=itemscope
    case org
      when :alphabetic
        [iscope.order('CONCAT(fullname, email) ASC'), 'CONCAT(fullname, email)' ]
      when :activity
        [iscope.where.not(current_sign_in_at: nil).order(current_sign_in_at: :DESC), :current_sign_in_at ]
      else
        super
    end
  end

  protected

  def supported_org_options
    [ :activity, :alphabetic ]
  end

end

class UserFriendsCache < ResultsCache
  include UserFunc
  include ModelSearch
  include CollectibleSearch

  def itemscope
    unless @itemscope
      @itemscope = user.followees
      @itemscope = @itemscope.viewed_by_user(@entity_id, viewer_id) if @entity_id != viewer_id
    end
    @itemscope
  end

  def orderingscope iscope=itemscope
    org ? super : [ iscope, {:fullname => :DESC, :email => :ASC}, 'fullname' ]
  end

  protected

  def supported_org_options
    [ :viewed, :newest ]
  end

end

# user's lists visible to current_user (UserListsStreamer
class UserListsCache < ResultsCache
  include ModelSearch
  include CollectibleSearch
  include TaggableSearch
  include UserFunc

  def itemscope
    @itemscope ||= user.decorate.owned_lists viewer
  end

end

class TagsIndexCache < ResultsCache
  include TagSearch
  # include EntitiesCache
  # Use the org parameter and the ASC/DESC attribute to assert an ordering

  def max_window_size
    5
  end

  protected

  def supported_org_options
    [ :newest, :popularity, (:meaningless if admin_view) ]
  end

end

class TagsAssociatedCache < ResultsCache
  include TaggableSearch

  def tag
    @tag ||= Tag.find @entity_id
  end

  def itemscope
    @itemscope ||= tag.taggings.where.not(entity_type: 'PageRef')
  end

end

class ReferentsAssociatedCache < ResultsCache
  include ModelSearch
  include CollectibleSearch
  include TaggableSearch

  def supported_org_options
    [  ]
  end

  def referent
    @referent ||= Referent.find_by id: @entity_id
  end

  # Everything tagged by any of the referent's tags, EXCEPT page_refs, lists, feeds and sites
  def itemscope
    # @itemscope ||= Tagging.where(entity_type: %w{ FeedEntry Recipe }, tag_id: referent.tag_ids)
    return @itemscope if @itemscope
    @itemscope ||= Recipe.joins(:taggings).where(taggings: { entity_type: Recipe, tag_id: referent.tag_ids } ).uniq
  end
end

class SitesIndexCache < ResultsCache
  include ModelSearch
  include CollectibleSearch
  include TaggableSearch

  def self.params_needed
    super + [:approved]
  end

  def supported_org_options
    [ :newest, (:viewed if viewer.current?), (:approved if admin_view) ]
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
          [nil, false]
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
    @itemscope ||= ((viewer_id == User.guest_id) ? Site.unscoped : Site.including_user_pointer(viewer_id)).
        includes(:page_ref, :thumbnail, :approved_feeds, :recipes => [:page_ref], :referent => [:canonical_expression]).
        where(approved: approved)
  end

  def orderingscope iscope=itemscope
    # Use the org parameter and the ASC/DESC attribute to assert an ordering
    case org # Blithely assuming a singular itemscope
      when :referent_id
      when :recipe_count
      when :feed_count
      when :definition_count
      when :approved
        [ iscope, (admin_view ? '"sites"."approved"' : '"sites"."id"') ]
      when :newest
        [ iscope, '"sites"."created_at" DESC', '"sites"."created_at"' ]
    end || super
  end

end

class SitesShowCache < ResultsCache
  include ResultTyping
  include ModelSearch

  def site
    @site = Site.find @entity_id
  end

  def itemscope
    @itemscope ||= site.contents_scope result_type.model_class
  end
end

class SitesAssociatedCache < SitesShowCache

end

class ImageReferencesIndexCache < ResultsCache
  include ModelSearch

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
    'ImageReference'
  end

  def itemscope
    @itemscope ||= ImageReference.unscoped
  end

end

class ImageReferenceCache < ResultsCache

  def reference
    @reference ||= ImageReference.find @entity_id
  end

end

class ReferentsIndexCache < ResultsCache
  include ModelSearch

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
    @itemscope ||= (typeclass == 'Referent') ? Referent.unscoped : Referent.where(type: typeclass)
  end

end

class ReferentCache < ResultsCache

end
