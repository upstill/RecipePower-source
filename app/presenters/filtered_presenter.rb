# This class bundles up the parameters used in views off the presenter.
class ViewParams
  attr_reader :link_address, :result_type, :results_path, :filtered_presenter, :item_mode

  delegate :entity, :decorator, :viewer, :tagtype,
           :request_path, :next_path,
           :filter_field, :filter_type_selector,
           :table_headers, :stream_id, :tail_partial, :sibling_views, :org_buttons,
           :presentation_partials, :results_partial, :org,
           :to => :filtered_presenter

  # Use a filtered presenter and a subtype to define the parameters
  def initialize fp, qparams={}
    @result_type = ResultType.new qparams[:result_type] || fp.result_type || ''
    @link_address = fp.response_service.decorate_path qparams
    @results_path = assert_query fp.results_path, qparams
    @item_mode = qparams[:item_mode] || fp.item_mode
    @filtered_presenter = fp
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
    if (user = filtered_presenter.entity) && (user.class == User) && result_type
      is_me = (user == filtered_presenter.viewer)
      is_friend = filtered_presenter.viewer.follows? user
      salutation = (is_friend ? user.salutation : user.polite_name).downcase
      if short
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
      result_type.downcase.pluralize
    end
  end

  def panel_label
    if result_type.present?
      result_type == 'lists' ? 'treasuries' : result_type.root
    else
      'collection'
    end
  end

  def display_style
    if (['friends', 'users', '', nil].include? result_type) && entity && (entity.class == User)
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
  def self.build view_context, sessid, request_path, response_service, params, querytags, decorator=nil
    classname = "#{response_service.controller.capitalize}#{response_service.action.capitalize}Presenter"

    if Object.const_defined? classname # If we have a FilteredPresenter subclass available
      classname.constantize.new view_context, sessid, request_path, response_service, params, querytags, decorator
    end
  end

  def initialize view_context, sessid, request_path, response_service, params, querytags, decorator=nil
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
        response_service.item_mode || # Provisionally accept item mode imposed by param
            (self.class.instance_variable_get(:'@item_mode') rescue nil) ||
            (:table if response_service.action == 'index')
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
    @request_path = request_path
    # FilteredPresenters don't always have results panels
    init_stream ResultsCache.retrieve_or_build( sessid, querytags, params)
    @viewparams = ViewParams.new self
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
    (defined?(super) ? super : []) + [ :tagtype, :result_type, :id, [ :content_mode, :container ], [ :org, :newest ] ]
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

  # Default results list: only the result type. Subclasses may redefine for multiple output types
  def subtypes
    [ result_type ]
  end

  def sibling_types
    [ ]
  end

  def show_card?
    @decorator && @decorator.object && @decorator.object.is_a?(Collectible)
  end

  def show_comments?
    @decorator && @decorator.object && @decorator.object.is_a?(Commentable)
  end

  def presentation_partial name, locals={}
      name.is_a?(Symbol) ? h.render_item(name, locals) : h.render(name, locals)
  end

  # The default presentation is different for tables and for objects, which in turn
  # may define multiple results panels
  def presentation_partials &block
    apply_partial :card, block if show_card?
    apply_partial :comments, block if show_comments?
    apply_partial header_partial, block if subtypes.count > 0
    if item_mode == :table
      apply_partial 'filtered_presenter/partial_table', block, :item_mode => :table
    elsif subtypes.count == 1
      apply_partial 'filtered_presenter/partial_spew', block, :item_mode => item_mode, :org => org
    else
      apply_partial 'filtered_presenter/partial_associated',
                    subtypes,
                    block,
                    :item_mode => item_mode,
                    :org => org
    end
  end

  def header_partial
    'filtered_presenter/generic_results_header'
  end

  # Define buttons used in the search/redirect header above the presenter's results
  def org_buttons context, &block
    # block.call 'RECENTLY VIEWED', '#'
  end

  # Specify a path for fetching the results partial, based on the current query
  def results_path qparams={}
    assert_query request_path, { content_mode: 'results', item_mode: item_mode }.merge(qparams)
  end

  # This is the name of the partial used to render my results
  def results_partial
    "filtered_presenter/results_#{item_mode}"
  end

  def tail_partial
    "filtered_presenter/tail_#{item_mode}"
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
  def apply_partial partial_name, subtype_or_subtypes, block=nil, qparams={}
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

  # Default results list: only the result type. Subclasses may redefine appropriately
  def subtypes
    result_type ? [ result_type ] : %w{ recipes lists feeds users }
  end

  def sibling_types
    %w{ lists recipes feeds users } - [ result_type ]
  end

  def header_partial
    'filtered_presenter/associated_results_header'
  end

  # The global query will be maintained
  def global_querytags
    querytags
  end

end

class UsersIndexPresenter < FilteredPresenter
  @item_mode = :table

  def result_type
    'users'
  end

  def table_headers
    [ '', 'About', 'Interest(s)', '', '' ]
  end

end

class RecipesAssociatedPresenter < FilteredPresenter

  # No results associated with recipes as yet
  def subtypes
    [ ]
  end

end

# Present a list of items for a user
class UserContentPresenter < FilteredPresenter

  def item_mode
    @item_mode ||= result_type.present? ? :masonry : :slider
  end

  # Here's where we translate from a result type (as provided by a pagelet) to
  # a series of subtypes to be displayed on the page in panels
  def subtypes
    case result_type
      when 'lists'
        %w{ lists.owned lists.collected }
      when nil, ''
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
        []
    end
  end

  def presentation_partials &block
    if result_type.present?
      apply_partial 'filtered_presenter/collection_entity_header', block
      # The contents partial will get defined once for every subtype in the results list
      apply_partial "filtered_presenter/partial_#{subtypes.count == 1 ? 'spew' : 'associated'}",
                    subtypes,
                    block,
                    :item_mode => :masonry, :org => :newest
    else
      apply_partial :card, block
      apply_partial 'filtered_presenter/generic_results_header', block
      apply_partial :panel, subtypes, block, :item_mode => :slider, :org => :newest
    end
  end

  # Define buttons used in the search/redirect header above the presenter's results
  def org_buttons context, &block
    size = context == 'panels' ? '' : ' small'
    block.call 'RECENTLY VIEWED', results_path(:org => :viewed), class: (org.to_sym == :viewed ? 'disabled' : '')+size
    block.call 'NEWEST', results_path(:org => :newest), class: (org.to_sym == :newest ? 'disabled' : '')+size
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
  @item_mode = :table

  def params_needed
    super + [ [ :sort_direction, 'DESC' ] ]
  end

  def result_type
    'feeds'
  end

  def table_headers
    [ '',
      '',
      '',
      'Host Site',
      'Status'.html_safe,
      ('' if admin_view),
      '' ].compact
  end

  def org_buttons context, &block
    current_mode = @sort_direction
    block.call 'newest first',
               results_path(:org => :newest, sort_direction: 'DESC'),
               title: 'Re-sort The List',
               class: (@sort_direction == 'DESC' ? 'disabled' : '')
    block.call 'oldest first',
               results_path(:org => :newest, sort_direction: 'ASC'),
               title: 'Re-sort The List',
               class: (@sort_direction == 'ASC' ? 'disabled' : '')
    if admin_view
      block.call 'unapproved first',
                 results_path(:org => :approved, sort_direction: 'DESC'),
                 title: 'Re-sort The List'
    end
    '' # No label
  end

end

# Present the entries associated with a list
class ListsIndexPresenter < FilteredPresenter
  @item_mode = :table

  def table_headers
    [ '', '', 'Author', 'Tags', 'Size', '' ]
  end

  def result_type
    'lists'
  end

end

class ListsShowPresenter < FilteredPresenter

  def result_type
    'list'
  end

  def subtypes
    [ 'list.contents' ]
  end

end

# Present the entries associated with a list
class ListsContentsPresenter < FilteredPresenter
  @item_mode = :masonry

  def result_type
    'list'
  end

  def subtypes
    [ 'list.contents' ]
  end

end

class ListsAssociatedPresenter < FilteredPresenter

  def result_type
    'list'
  end

  def subtypes
    [ 'lists.associated' ]
  end

end

# Present the entries associated with a list
class ReferencesIndexPresenter < FilteredPresenter
  @item_mode = :table

  def result_type
    'references'
  end

  def table_headers
    [ 'Reference Type', 'URL/Referees', '', '', '' ]
  end
end

# Present the entries associated with a list
class ReferentsIndexPresenter < FilteredPresenter
  @item_mode = :table

  def result_type
    'referents'
  end

  def table_headers
    [ 'Referent', '', '', '' ]
  end
end

class SitesIndexPresenter < FilteredPresenter
  @item_mode = :table

  def result_type
    'sites'
  end

  def table_headers
    [ '', 'Title<br>Description'.html_safe, 'Other Info', 'Actions' ]
  end

end

class TagsIndexPresenter < FilteredPresenter
  @item_mode = :table

  def result_type
    'tags'
  end

  def table_headers
    [ 'ID', 'Name', 'Type', 'Usages', 'Public?', 'Similar', 'Synonym(s)', 'Meaning(s)', '', '' ]
  end

  def filter_type_selector
    true
  end
end

# Present the entries associated with a list
class TagsAssociatedPresenter < FilteredPresenter
  @item_mode = :masonry

  def subtypes
    [ 'tags.associated' ]
  end

  def show_card?
    true
  end

end
