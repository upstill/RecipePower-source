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
            (response_service.action == "index" ? :table : :page)
    response_service.item_mode = @item_mode

    @content_mode =
        if params.has_key? :stream # The query is for items from the stream
          :items
        elsif params[:mode] && params[:mode] == "modal" # The query is for a modal dialog
          :modal
        elsif response_service.action == "show" # The query is to show the item
          :entity
        else
          @content_mode.to_sym # Either specified, or :container by default
        end

    @title = response_service.title
    @results_class = self.class.instance_variable_get(:"@results_class_name").constantize
    @stream_presenter = StreamPresenter.new sessid, request_path, @results_class, user_id, response_service.admin_view?, querytags, params
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

  def panel_partials &block
    # ["recipes", "lists", "friends", "feeds" ]
    ["recipes"].each do |et|
      block.call et, assert_query(results_path, entity_type: et, :item_mode => :slider, :org => :newest)
    end
  end

  # A filtered presenter may have a collection of other presenters to render in its stead, so we allow for a set
  def results_set &block
    block.call results_path, results_cssclass
  end

  # This is the class of the results container
  def results_cssclass
    @results_class || self.class
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

private

  def org= val
    @org = val.to_sym
  end

end

class UsersIndexPresenter < FilteredPresenter
  @item_mode = :table
  @results_class_name = 'UsersCache'

  def table_headers
    [ "", "About Me", "Interest(s)", "", "" ]
  end

  def pagelet
    super
  end
end

class UsersShowPresenter < FilteredPresenter
  @results_class_name = 'UserCollectionCache'

end

# Present a list of items for a user
class UserContentPresenter < FilteredPresenter
  attr_reader :entity_type

  def params_needed
    super << :entity_type
  end

  # A filtered presenter may have a collection of other presenters to render in its stead, so we allow for a set
  def results_set &block
    if @entity_type
      block.call results_path, results_cssclass
    else
      ["recipes", "lists", "friends", "feeds" ].each do |et|
         block.call assert_query(results_path, entity_type: et, item_mode: :slider), et
      end
    end
  end

  def results_cssclass
    @entity_type || self.class.to_s
  end
end

class UsersRecentPresenter < UserContentPresenter
  @results_class_name = 'UserRecentCache'

end

class UsersCollectionPresenter < UserContentPresenter
  @item_mode = :slider
  @results_class_name = 'UserCollectionCache'

end

class UsersBiglistPresenter < UserContentPresenter
  @results_class_name = 'UserBiglistCache'

end

# Present a list of feeds for a user
class FeedsShowPresenter < FilteredPresenter
  @item_mode = :page
  @results_class_name = 'FeedCache'

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

# Present the entries associated with a feed
class FeedsEntriesPresenter < FilteredPresenter
  @item_mode = :page
  @results_class_name = 'FeedCache'

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

  # A filtered presenter may have a collection of other presenters to render in its stead, so we allow for a set
  def results_set &block
    block.call results_path, results_cssclass
  end

end
