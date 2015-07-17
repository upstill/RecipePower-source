class FilteredPresenter

  attr_accessor :title, :h

  attr_reader :decorator, :entity,
              :results_class, # Class of the ResultsCache for fetching results
              :stream_presenter, # Manages the ResultsCache that produces items based on the query
              :content_mode, # What page element to render? :container, :entity, :results, :modal, :items
              :item_mode, # How composites are presented: :table, :strip, :masonry, :feed_item
              :org # How to organize the results: :ratings, :popularity, :newest, :random

  delegate :tail_partial, :querytags, :stream_id,
           :suspend, :next_item, :this_path,
           :full_size, :query, :param,
           :to => :stream_presenter

  # Build an instance of the appropriate subclass, given the entity, controller and action
  def self.build view_context, sessid, request_path, user_id, response_service, params, querytags, decorator=nil
    classname = "#{response_service.controller.capitalize}#{response_service.action.capitalize}Presenter"
    if Object.const_defined? classname # If we have a FilteredPresenter subclass available
      classname.constantize.new view_context, sessid, request_path, user_id, response_service, params, querytags, decorator
    end
  end

  # Declare the parameters that we adopt as instance variables. subclasses would add to this list
  def params_needed
    [ :tagtype, [:stream, ""], [ :content_mode, :container ], [ :org, :newest ] ]
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
    # @stream_param = params[:stream] || "" if params.has_key? :stream
    # @tagtype = params[:tagtype]
    @h = view_context

    # May have been set by subclass, may have been inherited from params
    @item_mode =
        response_service.item_mode || # Provisionally accept item mode imposed by param
            (self.class.instance_variable_get(:"@item_mode") rescue nil) ||
            (:table if response_service.action == "index")
    response_service.item_mode = @item_mode

    @content_mode =
        if params.has_key? :stream # The query is for items from the stream
          :items
        elsif params[:mode] && params[:mode] == "modal" # The query is for a modal dialog
          :modal
        else
          @content_mode.to_sym # Either specified, or :container by default
        end

    @title = response_service.title
    # FilteredPresenters don't always have results panels
    if rc_class = results_class
      @stream_presenter = StreamPresenter.new sessid, request_path, rc_class, user_id, response_service.admin_view?, querytags, params
    end
  end

  def results_class
    @results_class ||= (rcn = self.class.instance_variable_get :"@results_class_name") && rcn.constantize
  end

  # These elements go into the standard page for a presenter
  def page_elements
    [ :card, :comments, :owned ]
  end

  # Provide a tokeninput field for specifying tags, with or without the ability to free-tag
  # The options are those of the tokeninput plugin, with defaults
  def filter_field options={}
    data = options[:data] || {}
    data[:hint] ||= "Narrow down the list"
    data[:pre] ||= querytags.collect { |tag| { id: tag.id, name: tag.name } }.to_json
    data[:"min-chars"] ||= 2
    data[:query] = "tagtype=#{stream_presenter.tagtype}" if stream_presenter.tagtype

    options[:class] = "token-input-field-pending #{options[:class]}" # The token-input-field-pending class triggers tokenInput
    options[:onload] = "RP.tagger.onload(event);"
    options[:data] = data

    h.text_field_tag "querytags", querytags.map(&:id).join(','), options
  end

  def title_for subtype
    "No title defined for #{subtype}. Modify #{self.class} to provide one."
  end

  def partials &block
    et = respond_to?(:entity_type) && entity_type
    block.call "filtered_presenter/partial_null",
               "No partials defined#{(' for '+et) if et}. Define #{self.class}#partials to provide some",
               et,
               results_path
  end

  # This is the class of the results container
  def results_type
    (@results_class || self.class).to_s
  end

  # This is the name of the partial used to render me
  def results_partial
    "filtered_presenter/results_#{@item_mode}"
  end

  def tail_partial
    "filtered_presenter/tail_#{@item_mode}"
  end

  # Specify a path for fetching the results partial
  def results_path
    assert_query this_path, content_mode: "results", item_mode: @item_mode
  end

  # This is the name of the partial used for the header, presumably including the search box
  def header_partial
    "filtered_presenter/filter_header"
  end

  # What types of tag are suggested in the search
  def tagtype
    @tagtype || 0
  end

  def filter_type_selector
    false
  end

  # Should the items be dumped now?
  def dump?
    false # !instance_variable_defined?(:@stream_param)
  end

  # This is the path that will go into the "more items" link to fetch the next set
  # Rather than straight delegation, we may want to assert our own parameters here
  def next_path
    @stream_presenter.next_path
  end

  # Provide the query for revising the results
  def filter_query format=nil, params={}
    if format.is_a? Hash
      params, format = format, nil
    end
    # NB: here is where we can assert our own parameters for the query
    @stream_presenter.query format, params
  end

  # Return the name of the pagelet template
  def pagelet
    "filtered_presenter"
  end

  def stream_count force=false
    if stream_presenter.has_query? && (stream_presenter.ready? || force)
      case nmatches = stream_presenter.nmatches
        when 0
          "No matches found"
        when 1
          "1 match found"
        else
          "#{nmatches} found"
      end
    else
      case nmatches = stream_presenter.full_size
        when 0
          "Regrettably empty"
        when 1
          "Only one here"
        else
          "#{nmatches} altogether"
      end
    end
  end

  def panel_button_class
    "#{h.object_display_class decorator.object}-button"
  end

  def panel_label_class
    "#{h.object_display_class decorator.object}-label"
  end

  def panel_label
    case h.object_display_class(decorator.object)
      when "viewer"
        "my collection"
      when "friend", "user"
        "collection"
      when "recipe"
        "related"
    end
  end

private

  def org= val
    @org = val.to_sym
  end

end

class SearchIndexPresenter < FilteredPresenter
  @results_class_name = 'SearchCache'
  attr_reader :entity_type

  def params_needed
    super << :entity_type
  end

  def results_type
    @entity_type || self.class.to_s
  end

end

class UsersIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'UsersCache'

  def table_headers
    [ "", "About Me", "Interest(s)", "", "" ]
  end
end

class UsersShowPresenter < FilteredPresenter
  @results_class_name = 'UserCollectionCache'

end

class RecipesShowPresenter < FilteredPresenter

end

class ListsShowPresenter < FilteredPresenter
  @results_class_name = 'ListCache'

  def results_type
    "recipes" # @entity_type || self.class.to_s
  end

  def params_needed
    super << :entity_type
  end

  def partials &block
    types = @entity_type ? [ results_type ] : ["recipes"]
    if @entity_type
      block.call "filtered_presenter/partial_owned", title_for(results_type), results_type, results_path
    else
      types.each { |type|
        block.call "filtered_presenter/partial_owned",
                   title_for(type),
                   type,
                   assert_query(results_path, entity_type: type, :item_mode => :masonry, :org => :newest)
      }
    end
  end

end

# Present a list of items for a user
class UserContentPresenter < FilteredPresenter
  attr_reader :entity_type

  def params_needed
    super << :entity_type
  end

  def title_for type
    type.downcase
  end

  # A filtered presenter may have a collection of other presenters to render in its stead, so we allow for a set
  def partials &block
    types = @entity_type ? [ @entity_type ] : [ "feeds" ] # [ "recipes", "lists", "friends", "feeds" ]
    if @entity_type
      block.call "filtered_presenter/partial_panel", title_for(@entity_type), @entity_type, results_path
    else
      types.each do |type|
         block.call "filtered_presenter/partial_panel",
                    title_for(type),
                    type,
                    assert_query(results_path, entity_type: type, item_mode: :slider, :org => :newest)
      end
    end
  end

  def results_type
    (@entity_type || self.class.to_s)
  end
end

class UsersAssociatedPresenter < UserContentPresenter

  # The page for elements associated with a user has its own view
  def page_elements
    [ :associated ]
  end

  def results_class
    rcname = "UserCollectionCache" # ... by default
        case @entity_type
          when "lists.owned"
            rcname = "UserOwnedListsCache"
        end
    rcname && rcname.constantize
  end

  # Define the URL for each subtype (if any) vectoring off of this @result_type
  def partials &block
    if subtypes =
        case @entity_type
          when "lists"
            %w{ lists.owned lists.collected }
          when nil
            %w{ recipes lists friends feeds }
        end
    end
    if subtypes.blank?
      block.call "filtered_presenter/partial_spew", title_for(@entity_type), @entity_type, assert_query(results_path, entity_type: @entity_type, item_mode: :masonry)
    else
      subtypes.each do |subtype|
        block.call "filtered_presenter/partial_associated", title_for(subtype), subtype, assert_query(results_path, entity_type: subtype, item_mode: :masonry)
      end
    end
  end

  def title_for subtype
    is_me = @stream_presenter.results.user.id == h.current_user_or_guest_id
    salutation = @stream_presenter.results.user.salutation.downcase
    case subtype
      when "recipes"
        is_me ? "recipes I've collected" : "recipes collected by #{salutation}"
      when "lists.owned"
        is_me ? "my own lists" : "#{salutation}'s own lists"
      when "lists.collected"
        is_me ? "lists I've collected" : "lists collected by #{salutation}"
      when "friends"
        is_me ? "people I'm following" : "friends of #{salutation}"
      when "feeds"
        is_me ? "feeds I'm following" : "feeds followed by #{salutation}"
      else
        "#{subtype.gsub('.', '')} by #{is_me ? "me" : salutation}"
    end
  end

end

class UsersRecentPresenter < UserContentPresenter
  @results_class_name = 'UserRecentCache'

end

class UsersCollectionPresenter < UserContentPresenter
  @item_mode = :slider
  @results_class_name = 'UserCollectionCache'

  def results_class
    rc_class = (@entity_type == 'friends') ? "UserFriendsCache" : "UserCollectionCache"
    rc_class.constantize
  end

end

class UsersBiglistPresenter < UserContentPresenter
  @results_class_name = 'UserBiglistCache'

end

# Present a list of feeds for a user
class FeedsOwnedPresenter < FilteredPresenter
  @results_class_name = 'FeedCache'

  def panel_label
    ""
  end

  def panel_label_class
    "feed-entries"
  end

  def results_type
    "feed_entries"
  end

  def partials &block
    block.call "filtered_presenter/partial_spew", "feeds", "feed_entries", assert_query(results_path, item_mode: "page" )
  end

end

# Present the entries associated with a feed
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
      "Approved",
      "Actions" ]
  end

end

# Present the entries associated with a list
class ListsContentsPresenter < FilteredPresenter
  @item_mode = :masonry
  @results_class_name = 'ListCache'

end

# Present the entries associated with a list
class ListsIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'ListsCache'

  def table_headers
    %w{ Owner	Name	Description	Included Tags	Size }
  end
end

# Present the entries associated with a list
class ReferencesIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'ReferencesCache'

  def table_headers
    [ "Reference Type", "URL/Referees", "", "", "" ]
  end
end

# Present the entries associated with a list
class ReferentsIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'ReferentsCache'

  def table_headers
    [ "Referent", "", "", "" ]
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
    [ "ID", "Name", "Type", "Usages", "Public?", "Similar", "Synonym(s)", "Meaning(s)", "", "" ]
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
