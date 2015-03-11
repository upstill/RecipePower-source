class FilteredPresenter

  attr_reader :decorator, :entity, :querytags,
              :results_class, # Class of the ResultsCache for fetching results
              :list_class, # Class of the presented entity (i.e., users for lists)
              :content_mode, # What page element to render? :container, :entity, :results, :modal, :items
              :list_mode # How composites are presented: :table, :strip, :masonry

  # Build an instance of the appropriate subclass, given the entity, controller and action
  def self.build response_service, params, querytags, decorator=nil
    classname = response_service.controller.capitalize + response_service.action.capitalize + "Presenter"
    p = classname.constantize.new
    p.setup response_service, params, querytags, decorator
    p
  end

  def setup response_service, params, querytags, decorator=nil
    if @decorator = decorator
      @entity = decorator.object
      @list_class = @entity.class.to_s.pluralize.underscore
    end
    @stream_param = params[:stream] || "" if params.has_key? :stream
    @tagtype = params[:tagtype]
=begin
    if @stream_param.blank?
      offset = 0
    else
      offset, limit = @stream_param.split('-').map(&:to_i)
    end
=end
    @thispath = response_service.requestpath
    @list_mode = (params[:list_mode] || :masonry).to_sym
    @content_mode = (params[:content_mode] || :container).to_sym
    @content_mode = :entity if response_service.action == "show"
    @content_mode = :modal if params[:mode] && params[:mode] == "modal"
    @content_mode = :items if params.has_key? :stream
    @querytags = querytags
  end

  # Render the header card for the entity
  def entity_partial
    "#{@entity.class.to_s.pluralize.underscore}/show_header" if @entity
  end

  # A filtered presenter may have a collection of other presenters to render in its stead, so we allow for a set
  def results_set
    [ self ]
  end

  # This is the class of the results container
  def results_class
    self.class.to_s
  end

  # This is the name of the partial used to render me
  def results_partial
    "filtered_presenter/results_#{@list_mode}"
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

  # Provide the query for revising the results
  def filter_query format=nil, params={}
    if format.is_a? Hash
      params, format = format, nil
    end
    assert_query @thispath, format, params.merge( stream: nil, querytags: nil )
  end

  # Return the name of the pagelet template
  def pagelet
    "filtered_presenter"
  end

end

class UsersIndexPresenter < FilteredPresenter

  def initialize
    super
    @results_class = UsersCache
  end

  def table_headers
    [ "", "About Me", "Interest(s)", "", "" ]
  end
end

class UsersShowPresenter < FilteredPresenter

  def initialize
    super
    @results_class = UserCollectionCache
  end
end

class UsersRecentPresenter < FilteredPresenter

  def initialize
    super
    @results_class = UserRecentCache
  end
end

class UsersCollectionPresenter < FilteredPresenter

  def initialize
    super
    @results_class = UserCollectionCache
  end
end

class UsersBiglistPresenter < FilteredPresenter

  def initialize
    super
    @results_class = UserBiglistCache
  end
end