class FilteredPresenter

  attr_accessor :title, :h

  attr_reader :decorator, :entity,
              :entity_type, :results_type, # :header_partial,
              :results_class, # Class of the ResultsCache for fetching results
              :stream_presenter, # Manages the ResultsCache that produces items based on the query
              :content_mode, # What page element to render? :container, :entity, :results, :modal, :items
              :item_mode, # How composites are presented: :table, :strip, :masonry, :feed_item
              :org # How to organize the results: :ratings, :popularity, :newest, :random

  delegate :tail_partial, :stream_id,
           :suspend, :next_item, :this_path, :next_path,
           :full_size, :query, :param, :querytags,
           :to => :stream_presenter

  # Build an instance of the appropriate subclass, given the entity, controller and action
  def self.build view_context, sessid, request_path, user_id, response_service, params, querytags, decorator=nil
    classname = "#{response_service.controller.capitalize}#{response_service.action.capitalize}Presenter"

    if Object.const_defined? classname # If we have a FilteredPresenter subclass available
      classname.constantize.new view_context, sessid, request_path, user_id, response_service, params, querytags, decorator
    end
  end

  def initialize view_context, sessid, request_path, user_id, response_service, params, querytags, decorator=nil
    if @decorator = decorator
      @entity = decorator.object
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
    # @stream_param = params[:stream] || '' if params.has_key? :stream
    @h = view_context

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
    # This is the name of the partial used for the header, presumably including the search box
    # @header_partial = 'filtered_presenter/filter_header'
    # FilteredPresenters don't always have results panels
    if rc_class = results_class
      @stream_presenter = StreamPresenter.new sessid, request_path, rc_class, user_id, response_service.admin_view?, querytags, params
    end
  end

  # Declare the parameters that we adopt as instance variables. subclasses would add to this list
  def params_needed
    [ :tagtype, :entity_type, [:stream, ''], [ :content_mode, :container ], [ :org, :newest ] ]
  end

  def results_class
    @results_class ||= (rcn = self.class.instance_variable_get :'@results_class_name') && rcn.constantize
  end

  def title_for subtype
    subtype.downcase
  end

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
    h.token_input_query opt_param.merge(tagtype: tagtype, querytags: querytags)
  end

  # Should the items be dumped now?
  def dump?
    false # !instance_variable_defined?(:@stream_param)
  end

  # Provide the query for revising the results
  def filter_query format=nil, params={}
    if format.is_a? Hash
      params, format = format, nil
    end
    # NB: here is where we can assert our own parameters for the query
    @stream_presenter.query format, params
  end

  def display_class
    decorator ? h.object_display_class(decorator.object) : self.class.to_s.underscore.sub(/_.*/,'').singularize
  end

  def panel_button_class
    "#{display_class}-button"
  end

  def panel_label_class
    "#{display_class}-label"
  end

  def panel_label
    case display_class
      when 'viewer'
        'my collection'
      when 'friend', 'user'
        'collection'
      when 'recipe'
        'related'
      when 'feed'
        'entries'
      when 'list'
        'contents'
      else
        display_class
    end
  end

  def stream_count force=false
    if stream_presenter.has_query? && (stream_presenter.ready? || force)
      case nmatches = stream_presenter.nmatches
        when 0
          'No matches found'
        when 1
          '1 match found'
        else
          "#{nmatches} found"
      end
    else
      case nmatches = stream_presenter.full_size
        when 0
          'Regrettably empty'
        when 1
          'Only one here'
        else
          "#{nmatches} altogether"
      end
    end
  end

  # The types of tag to which the query is restricted
  def tagtype
    stream_presenter && stream_presenter.tagtype
  end

  ### The remaining public methods pertain to the page presentation

  def results_list
    [entity_type || results_type]
  end

  def header_partial
    'filtered_presenter/generic_results_header'
  end

  def contents_partial
    (results_list.count == 1) ? 'filtered_presenter/partial_spew' : 'filtered_presenter/partial_associated'
  end

  # The default presentation is different for tables and for objects, which in turn
  # may define multiple results panels
  def presentation_partials &block
    if item_mode == :table
      block.call header_partial
      block.call 'filtered_presenter/results_table'
    else
      if @decorator && @decorator.object && @decorator.object.is_a?(Collectible)
        block.call :card
        block.call :comments
      end
      block.call header_partial, title: panel_label
      return unless results_list.present?
      apply_partial contents_partial,
                    results_list,
                    block,
                    :item_mode => item_mode,
                    :org => org
    end
  end

  # Define buttons used in the search/redirect header above the presenter's results
  def header_buttons &block
    # block.call 'RECENTLY VIEWED', '#'
  end

  # This is the class of the results container
  def results_type
    (@results_class || self.class).to_s
  end

  # Specify a path for fetching the results partial
  def results_path
    assert_query (@stream_presenter ? this_path : @request_path), content_mode: 'results', item_mode: item_mode
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

protected

  # Invoke a partial for one or more types
  def apply_partial partial_name, type_or_types, block, qparams={}
      [type_or_types].flatten.compact.each { |type|
        block.call partial_name,
                   title: title_for(type),
                   type: type,
                   url: assert_query(results_path, qparams.merge(entity_type: type))
      }
  end

  private

  def querytags
    stream_presenter ? stream_presenter.querytags : []
  end

  def org= val
    @org = val.to_sym
  end

end

class SearchIndexPresenter < FilteredPresenter
  @results_class_name = 'SearchAllCache'

  def entity_type
    @entity_type ||= 'recipes'
  end

  def results_type
    entity_type || self.class.to_s
  end

  def display_class
    'search'
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
  @results_class_name = 'UsersCache'

  def table_headers
    [ '', 'About Me', 'Interest(s)', '', '' ]
  end
end

class UsersShowPresenter < FilteredPresenter
  @results_class_name = 'UserCollectionCache'

end

class RecipesAssociatedPresenter < FilteredPresenter

  # No results associated with recipes as yet
  def results_list
  end

end

# Present a list of items for a user
class UserContentPresenter < FilteredPresenter

  def item_mode
    @item_mode = :slider unless @entity_type
    @item_mode
  end

  def title_for type
    if item_mode == :slider
      h.user_associated_label(type).downcase
    else
      is_me = @stream_presenter.results.user.id == h.current_user_or_guest_id
      salutation = @stream_presenter.results.user.salutation.downcase
      case type
        when 'recipes'
          is_me ? 'recipes I\'ve collected' : "recipes collected by #{salutation}"
        when 'lists.owned'
          is_me ? 'my own lists' : "#{salutation}'s own lists"
        when 'lists.collected'
          is_me ? 'lists I\'ve collected' : "lists collected by #{salutation}"
        when 'friends'
          is_me ? 'people I\'m following' : "friends of #{salutation}"
        when 'feeds'
          is_me ? 'feeds I\'m following' : "feeds followed by #{salutation}"
        else
          "#{type.gsub('.', '')} by #{is_me ? 'me' : salutation}"
      end
    end
  end

  def results_list
    case @entity_type
      when 'lists'
        %w{ lists.owned lists.collected }
      when nil
        %w{ recipes feeds friends lists }
      else
        [ @entity_type ]
    end
  end

  def presentation_partials &block
    if @entity_type
      block.call 'filtered_presenter/collection_entity_header'
      apply_partial contents_partial, results_list, block, :item_mode => :masonry, :org => :newest
    else
      block.call :card
      block.call 'filtered_presenter/generic_results_header'
      apply_partial :panel, results_list, block, :item_mode => :slider, :org => :newest
    end
  end

  # Define buttons used in the search/redirect header above the presenter's results
  def header_buttons &block
    block.call 'RECENTLY VIEWED', '#'
    block.call 'EVERYTHING', '#'
  end

  def results_type
    (@entity_type || self.class.to_s)
  end
end

class UsersCollectionPresenter < UserContentPresenter
  # @results_class_name = 'UserCollectionCache'
  # @item_mode = :slider
  # @item_mode = :masonry

  def results_class
    rcname =  # ... by default
        case @entity_type
          when 'lists.owned'
            'UserOwnedListsCache'
          when 'friends'
            'UserFriendsCache'
        end || 'UserCollectionCache'
    rcname.constantize
  end

end

class UsersRecentPresenter < UserContentPresenter
  @results_class_name = 'UserRecentCache'

end


class UsersBiglistPresenter < UserContentPresenter
  @results_class_name = 'UserBiglistCache'

end

# Present the entries associated with a feed
class FeedsOwnedPresenter < FilteredPresenter
  @results_class_name = 'FeedCache'

  def results_type
    'feed_entries'
  end

  def item_mode
    :page
  end

end

# Present a list of feeds for a user
class FeedsIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'FeedsCache'

  def table_headers
    [ 'Title/Description/URL',
      'Tag(s)',
      'Type',
      'Host Site',
      '# Entries/
Last Updated',
      'Approved',
      'Actions' ]
  end

  def panel_label
    'feeds'
  end

  def header_buttons &block
    current_mode = stream_presenter.results.params[:access]
    current_path = (@stream_presenter ? this_path : @request_path)
    block.call 'newest first', (assert_query(current_path, access: 'newest') if current_mode != 'newest')
    block.call 'oldest first', (assert_query(current_path, access: 'oldest') if current_mode != 'oldest')
  end

end

# Present the entries associated with a list
class ListsIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'ListsCache'

  def table_headers
    %w{ Owner	Name	Description Tags	Size }
  end

  def panel_label
    'all the lists'
  end
end

class ListsShowPresenter < FilteredPresenter
  @results_class_name = 'ListCache'

  def entity_type
    @entity_type ||= 'recipes'
  end

  def results_type
    'recipes'
  end

end

# Present the entries associated with a list
class ListsContentsPresenter < FilteredPresenter
  @item_mode = :masonry
  @results_class_name = 'ListCache'

end

class ListsAssociatedPresenter < FilteredPresenter

end

# Present the entries associated with a list
class ReferencesIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'ReferencesCache'

  def table_headers
    [ 'Reference Type', 'URL/Referees', '', '', '' ]
  end
end

# Present the entries associated with a list
class ReferentsIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'ReferentsCache'

  def table_headers
    [ 'Referent', '', '', '' ]
  end
end

class SitesIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'SitesCache'

  def table_headers
    %W{ Site Description Further\ Info Actions }
  end

end

class TagsIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'TagsCache'

  def table_headers
    [ 'ID', 'Name', 'Type', 'Usages', 'Public?', 'Similar', 'Synonym(s)', 'Meaning(s)', '', '' ]
  end

  def filter_type_selector
    true
  end

end

# Present the entries associated with a list
class TagsTaggeesPresenter < FilteredPresenter
  @item_mode = :masonry
  @results_class_name = 'TagCache'

end
