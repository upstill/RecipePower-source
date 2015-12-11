module FeedsTable
  @item_mode = :table
  def table_headers
    [ '',
      '',
      '',
      'Host Site',
      'Status'.html_safe,
      ('' if admin_view),
      '' ].compact
  end
end

module SitesTable
  @item_mode = :table
  def table_headers
    [ '', 'Title<br>Description'.html_safe, 'Other Info', 'Actions' ]
  end
end

module ListsTable
  @item_mode = :table
  def table_headers
    [ '', '', 'Author', 'Tags', 'Size', '' ]
  end
end

module TagsTable
  @item_mode = :table
  def table_headers
    [ 'ID', 'Name', 'Type', 'Usages', 'Public?', 'Similar', 'Synonym(s)', 'Meaning(s)', '', '' ]
  end
end

module ReferencesTable
  @item_mode = :table
  def table_headers
    ['Reference Type', 'URL/Referees', '', '', '']
  end
end

module ReferentsTable
  @item_mode = :table
  def table_headers
    [ 'Referent', '', '', '' ]
  end
end

module UsersTable
  @item_mode = :table
  def table_headers
    [ '', 'About', 'Interest(s)', '', '' ]
  end
end

# This class bundles up the parameters used in views off the presenter.
class ViewParams
  attr_reader :link_address, :result_type, :results_path, :filtered_presenter, :item_mode

  delegate :entity, :decorator, :viewer, :tagtype, :response_service,
           :request_path, :next_path, :query,
           :filter_field, :filter_type_selector,
           :table_headers, :stream_id, :tail_partial, :sibling_views, :org_buttons,
           :presentation_partials, :results_partial, :org,
           :to => :filtered_presenter

  # Use a filtered presenter and a subtype to define the parameters
  def initialize fp, qparams={}
    @result_type = ResultType.new qparams[:result_type] || fp.result_type || ''
    @filtered_presenter = fp
    @link_address = fp.response_service.decorate_path qparams
    @results_path = assert_query fp.results_path, qparams
    @item_mode = qparams[:item_mode] || (fp && fp.item_mode)
  end

    # For use in the address bar
  def page_title
    case display_style
      when 'viewer'
        'my collection'
      when 'friend'
        "#{entity.salutation.downcase}'s collection"
      when 'user'
        "#{entity.polite_name.downcase}'s collection"
      when 'recipe'
        'related'
      when 'feed'
        'feeds'
      when 'list'
        'contents'
      when 'feed_entry'
        'entries'
      else
        display_style.pluralize
    end
  end

  def panel_title short=false
    if (user = filtered_presenter.entity) && (user.class == User)
      is_me = (user == filtered_presenter.viewer)
      is_friend = filtered_presenter.viewer.follows? user
      salutation = (is_friend ? user.salutation : user.polite_name).downcase
      if short || result_type.blank?
        %Q{#{is_me ? 'my' : salutation+'\'s'} #{panel_label}}
      else
        case result_type
          when 'recipes'
            is_me ? "#{panel_label} I've collected" : "#{panel_label} collected by #{salutation}"
          when 'lists.owned'
            is_me ? "my own #{panel_label}" : "#{salutation}'s own #{panel_label}"
          when 'lists.collected'
            is_me ? "#{panel_label} I've collected" : "#{panel_label} collected by #{salutation}"
          when 'friends'
            is_me ? 'people I\'m following' : "people #{salutation} is following"
          when 'feeds'
            is_me ? 'feeds I\'m following' : "feeds followed by #{salutation}"
          else
            "#{panel_label.capitalize} by #{is_me ? 'me' : salutation}"
        end
      end
    else
      panel_label.downcase.pluralize
    end
  end

  def panel_label
    case result_type.root
      when 'lists'
        'treasuries'
      when 'feed_entries'
        'entries'
      else
        result_type.root
    end
  end

  def display_style specific=true
    if specific && (['friends', 'users', 'collection', '', nil].include? result_type) && entity && (entity.class == User)
      if entity == viewer
        'viewer'
      elsif viewer.follows? entity
        'friend'
      else
        'user'
      end
    else
      result_type.root.singularize
    end
  end
end

class FilteredPresenter
  include StreamPresentation # Provides a streaming interface to the results cache
  require './app/models/results_cache.rb'
  attr_accessor :title, :h

  attr_reader :request_path, :decorator, :entity, :viewer, :response_service, :result_type, :viewparams, :tagtype,
              :content_mode, # What page element to render? :container, :entity, :results, :modal, :items
              :item_mode, # How composites are presented: :table, :strip, :masonry, :feed_item
              :org, # How to organize the results: :ratings, :popularity, :newest, :viewed, :random
              :klass # class of the underlying object

  delegate :admin_view,
           :querytags, :"has_query?",
           :to => :results_cache

  delegate :display_style, :to => :viewparams

  # Build an instance of the appropriate subclass, given the entity, controller and action
  def self.build view_context, response_service, params, querytags, decorator=nil
    classname = "#{response_service.controller.capitalize}#{response_service.action.capitalize}Presenter"

    if Object.const_defined? classname # If we have a FilteredPresenter subclass available
      classname.constantize.new view_context, response_service, params, querytags, decorator
    end
  end

  # Build a filtered_presenter for the purpose of showing an object
  def self.build_from_decorator decorator, view_context, response_service, params
    classname = "#{decorator.object.class.to_s.pluralize}ShowPresenter"
    if Object.const_defined? classname
      classname.constantize.new view_context, response_service, {}, [], decorator
    end
  end

  def initialize view_context, response_service, params, querytags, decorator=nil
    if @decorator = decorator
      @entity = decorator.object
      @klass = @entity.class
    else
      name = params['controller'].sub(/Controller$/, '').singularize.capitalize
      @klass = name.constantize rescue nil
    end

    params_needed.each { |pspec|
      key, val = (pspec.is_a? Array) ? pspec : [pspec]
      val = params[key] if params[key]
      setter = "#{key}="
      if self.respond_to? setter, true
        self.method(setter).call val
      else
        self.instance_variable_set "@#{key}".to_sym, val
      end
    }
    params[:result_type] = result_type # Give subclasses a chance to weigh in on a default
    @h = view_context
    @response_service = response_service
    @viewer = @response_service.user

    # May have been set by subclass, may have been inherited from params
    # Set the instance variable, possibly in consultation with the class
    @item_mode =
        params[:item_mode] || # Provisionally accept item mode imposed by param
            (self.class.instance_variable_get(:'@item_mode') rescue nil) ||
            (:table if response_service.action == 'index')
    @item_mode = @item_mode.to_sym if @item_mode
    # Allow the class to define the item mode on its own
    response_service.item_mode = item_mode

    @content_mode =
        if params.has_key? :stream # The query is for items from the stream
          :items
        elsif params[:mode] && params[:mode] == 'modal' # The query is for a modal dialog
          :modal
        else
          @content_mode.to_sym # Either specified, or :container by default
        end

    @title = response_service.title
    @request_path = response_service.requestpath
    @viewparams = ViewParams.new self
    # Notify the ResultsCache(s) of any prospective results query
    init_stream ResultsCache.retrieve_or_build( response_service.uuid, subtypes, querytags, params).first
  end

  # This is the path that will go into the "more items" link
  def next_path
    assert_query request_path, stream_params_next if stream_params_next
  end

  # The query for applying querytags is the same as this one, without :stream, :querytags or :nocache
  def query format=nil, params={}
    if format.is_a? Hash
      params, format = format, nil
    end
    assert_query request_path, format, params.merge(stream_params_null).merge(querytags: nil)
  end

  # This is a stub for future use in eliding streaming
  def dump?
    false
  end

  # Declare the parameters that we adopt as instance variables. subclasses would add to this list
  def params_needed
    (defined?(super) ? super : []) +
        [ :tagtype, :result_type, :id, [ :content_mode, :container ], [ :org, :newest ], [ :sort_direction, 'DESC' ] ]
  end

  # Include a (tag) type selector in the query field?
  def filter_type_selector
    false
  end

  # This method will be over-ridden by any class that takes its querytags from the global query box
  def global_querytags
    []
  end

  ### Methods not overridden

  # Provide a tokeninput field for specifying tags, with or without the ability to free-tag
  # The options are those of the tokeninput plugin, with defaults
  def filter_field opt_param={}
    h.token_input_query opt_param.merge(tagtype: tagtype, querytags: querytags, type_selector: filter_type_selector).compact
  end

  def stream_count force=false
    if results_cache.has_query? && (results_cache.ready? || force)
      case nmatches = results_cache.nmatches
        when 0
          'No matches found'
        when 1
          '1 match found'
        else
          "#{nmatches} found"
      end
    else
      case nmatches = results_cache.full_size
        when 0
          'Regrettably empty'
        when 1
          'Only one here'
        else
          "#{nmatches} altogether"
      end
    end
  end

  ### The remaining public methods pertain to the page presentation

  # Default results list: only the result type. Subclasses may redefine for multiple subtypes
  def subtypes
    [ result_type ].compact
  end

  # Other result types that may be provided alternative to the current one
  def sibling_types
    [ ]
  end

  def show_card?
    @decorator && @decorator.object && @decorator.object.is_a?(Collectible)
  end

  def show_comments?
    @decorator && @decorator.object && @decorator.object.is_a?(Commentable)
  end

  # The default presentation is different for tables and for objects, which in turn
  # may define multiple results panels
  def presentation_partials &block
    presentation_partial :card, block if show_card?
    presentation_partial :comments, block if show_comments?
    presentation_partial header_partial, block if subtypes.count > 0
    presentation_partial body_partial, subtypes, block, :item_mode => item_mode, :org => org
  end

  def header_partial
    'header_generic'
  end

  def body_partial
    if item_mode == :table
      'partial_table'
    else
      subtypes.count == 1 ? 'partial_spew' : 'partial_associated'
    end
  end

  # Define buttons used in the search/redirect header above the presenter's results
  def org_buttons context, &block
    block.call 'RECENTLY VIEWED', { :org => :viewed }
  end

  # Specify a path for fetching the results partial, based on the current query
  def results_path qparams={}
    assert_query request_path, { content_mode: 'results', item_mode: item_mode }.merge(qparams)
  end

  # This is the name of the partial used to render my results
  def results_partial
    "results_#{item_mode}"
  end

  def tail_partial
    "tail_#{item_mode}"
  end

  def item_mode
    @item_mode || :masonry
  end

  def sibling_views
    sibling_types.collect { |subtype|
      ViewParams.new(self, result_type: subtype) if subtype != result_type
    }.compact
  end

protected

  # Invoke a partial for one or more subtypes.
  # If the list of subtypes is nil, just use the viewparams for the presenter itself
  def presentation_partial partial_name, subtype_or_subtypes, block=nil, qparams={}
    subtype_or_subtypes, block = nil, subtype_or_subtypes if subtype_or_subtypes.is_a? Proc
    [subtype_or_subtypes].flatten.each { |subtype|
      block.call partial_name,
                 subtype ? ViewParams.new(self, qparams.merge(result_type: subtype)) : @viewparams
    }
  end

  private

  def querytags
    results_cache ? results_cache.querytags : []
  end

  def org= val
    @org = val.to_sym
  end

end

class SearchIndexPresenter < FilteredPresenter
  @item_mode = :masonry

  # The global search only presents one type at a time, starting with recipes
  def result_type
    super || 'recipes'
  end

  def sibling_types
    %w{ lists recipes feeds users } - [ result_type ]
  end

  def header_partial
    'header_associated_results'
  end

  # The global query will be maintained
  def global_querytags
    querytags
  end

end

class UsersIndexPresenter < FilteredPresenter
  include UsersTable

  def result_type
    'users'
  end

end

class RecipesAssociatedPresenter < FilteredPresenter

  def result_type
    'recipes.associated'
  end

  # No results associated with recipes as yet
  def subtypes
    [ ]
  end

end

# Present a list of items for a user
class UserContentPresenter < FilteredPresenter

  def result_type
    super || 'collection'
  end

  def item_mode
    @item_mode ||= result_type=='collection' ? :slider : :masonry
  end

  # Here's where we translate from a result type (as provided by a pagelet) to
  # a series of subtypes to be displayed on the page in panels
  def subtypes
    case result_type
      when 'lists'
        %w{ lists.owned lists.collected }
      when 'collection'
        %w{ recipes lists feeds friends }
      else
        super
    end
  end

  def sibling_types
    case result_type
      when 'lists.owned'
        [ 'lists.collected' ]
      when 'lists.collected'
        [ 'lists.owned' ]
      when 'recipes', 'lists', 'feeds', 'friends'
        %w{ lists recipes feeds friends } - [result_type]
      else
        super
    end
  end

  def header_partial
    viewparams.result_type.root == 'collection' ? 'header_generic' : 'header_collection_entity'
  end

  def body_partial
    return :panel if viewparams.result_type.root == 'collection'
    super
  end

  # Define buttons used in the search/redirect header above the presenter's results
  def org_buttons context, &block
    size = context == 'panels' ? '' : ' small'
    block.call 'RECENTLY VIEWED', { :org => :viewed, active: org.to_sym == :viewed }, class: size
    block.call 'NEWEST', { :org => :newest, active: org.to_sym == :newest }, class: size
    context == 'panels' ? '' : 'order by'
  end
end

class UsersShowPresenter < UserContentPresenter

end

class UsersCollectionPresenter < UserContentPresenter

end

class UsersRecentPresenter < UserContentPresenter

end

class UsersBiglistPresenter < UserContentPresenter

end

# Present the entries associated with a feed
class FeedsOwnedPresenter < FilteredPresenter

  def result_type
    'feed_entries'
  end

  def item_mode
    :page
  end

end

# Present a list of feeds for a user
class FeedsIndexPresenter < FilteredPresenter
  include FeedsTable

  def result_type
    'feeds'
  end

  def org_buttons context, &block
    current_mode = @sort_direction
    block.call 'newest first', { :org => :newest, :sort_direction => 'DESC', active: true },
               title: 'Re-sort The List',
               class: (@sort_direction == 'DESC' ? 'disabled' : '')
    block.call 'oldest first', { :org => :newest, sort_direction: 'ASC' },
               title: 'Re-sort The List',
               class: (@sort_direction == 'ASC' ? 'disabled' : '')
    if admin_view
      block.call 'unapproved first', { :org => :approved, sort_direction: 'ASC' },
                 title: 'Re-sort The List'
    end
    '' # No label
  end

end

class SitesShowPresenter < FilteredPresenter
  @item_mode = :slider

  def result_type
    super || 'feeds'
  end

end

class SitesFeedsPresenter < FilteredPresenter
  include FeedsTable

  def item_mode
    super || 'masonry'
  end

  def result_type
    'feeds'
  end
end

# Present the entries associated with a list
class ListsIndexPresenter < FilteredPresenter
  include ListsTable

  def result_type
    'lists'
  end

end

class ListsShowPresenter < FilteredPresenter

  def result_type
    'lists.contents'
  end

end

# Present the entries associated with a list
class ListsContentsPresenter < FilteredPresenter
  @item_mode = :masonry

  def result_type
    'lists.contents'
  end

end

class ListsAssociatedPresenter < FilteredPresenter

  def result_type
    'lists.associated'
  end

end

# Present the entries associated with a list
class ReferencesIndexPresenter < FilteredPresenter
  include ReferencesTable

  def result_type
    'references'
  end
end

# Present the entries associated with a list
class ReferentsIndexPresenter < FilteredPresenter
  include ReferentsTable

  def result_type
    'referents'
  end
end

class SitesIndexPresenter < FilteredPresenter
  include SitesTable

  def result_type
    'sites'
  end

end

class TagsIndexPresenter < FilteredPresenter
  include TagsTable

  def result_type
    'tags'
  end

  def filter_type_selector
    true
  end
end

# Present the entries associated with a list
class TagsAssociatedPresenter < FilteredPresenter
  @item_mode = :masonry

  def result_type
    'tags.associated'
  end

  def show_card?
    true
  end

end

# Present the entries associated with a list
class TagsShowPresenter < FilteredPresenter
  @item_mode = :masonry

  def result_type
    nil
  end

  def show_card?
    true
  end

end
