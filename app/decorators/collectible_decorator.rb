class CollectibleDecorator < ModelDecorator
  # include Draper::LazyHelpers
  include Templateer
  include DialogPanes
  delegate_all

  def sourcename

  end

  # Wrap a Linkable's glean method, returning the gleaning iff there is one, and it's not bad
  # Also, launch the gleaning as necessary
  def glean
    object.bkg_land if object.is_a?(Backgroundable)
    object.gleaning if object.respond_to?(:gleaning) && !object.gleaning&.bad?
  end

  # sample_page is a full URL somewhere on the associated site so we can absolutize links
  def sample_page

  end

  # Get the url from the associated ImageReference, possibly resolving a relative path with the help of a sample page
  # TODO There's no reason why this shouldn't be named 'imgurl'
  def picurl
    picurl = object.imgurl
    (picurl.present? && sample_page) ? valid_url(picurl, sample_page) : picurl
  end

  # Get the data from the associated ImageReference, possibly reducing its image URL to a data URL
  # TODO There's no reason why this shouldn't be named 'imgdata'
  def picdata
    object.imgdata
  end

  def pageurl
    if object.respond_to?(:url_attribute)
      pageurl = object.url_attribute
      (pageurl.present? && sample_page) ? valid_url(pageurl, sample_page) : pageurl
    end
  end

  # Declare the set of gleanings labels that we can handle
  def finderlabels
    %w{ Image Title Description }
  end

  # Specify what attribute should receive a given type of Result
  def attribute_name_for label
    case label
    when 'Title'
      :title
    when 'Description'
      :description
    when 'href', 'URI'
      object.url_attribute if object.respond_to?(:url_attribute)
    when 'Content'
      :content
    when 'Prep Time'
      :prep_time
    when 'Cooking Time'
      :cook_time
    when'Yield'
      :yield # self.yield = findings.result_for('Yield') if findings.result_for('Yield').present?
    when 'Image'
      object.picable_attribute if object.respond_to?(:picable_attribute)
    end
  end

  # Here's where we incorporate findings from a page into the corresponding entity
  def findings= findings
    def accept_result findings, result_name
      return unless (attrname = attribute_name_for(result_name)) &&
          findings.result_for(result_name) &&
          (value = findings.result_for(result_name)).present?
      klass = object.class
      attrname = attrname.to_sym
      if klass.respond_to?(:tracked_attributes) && klass.tracked_attributes.include?(attrname)
        object.accept_attribute attrname, value
      else
        setter = (attrname.to_s+'=').to_sym
        object.send setter, value if object.respond_to?(setter)
      end
    end
    accept_result findings, 'Title'
    accept_result findings, 'Description'
    accept_result findings, 'Content' # self.content = findings.result_for('Content') if findings.result_for('Content').present?
    # self.description = findings.result_for('Description') if findings.result_for('Description').present? && description.blank?
    ts = nil # TaggingService object
    if self.is_a? Recipe
      accept_result findings, 'Prep Time' # self.prep_time = findings.result_for('Prep Time') if findings.result_for('Prep Time').present?
      accept_result findings, 'Cooking Time' # self.cook_time = findings.result_for('Cooking Time') if findings.result_for('Cooking Time').present?
      if findings.result_for('Total Time').present?
        tt = Tag.assert (self.total_time = findings.result_for('Total Time')), :Time
        tt && ((ts ||= TaggingServices.new object).tag_with tt, User.super_id)
      end
      accept_result findings, 'Yield' # self.yield = findings.result_for('Yield') if findings.result_for('Yield').present?
    end
    accept_result findings,'Image'
    ts = nil
    {
        'Author' => 'Author',
        'Course' => 'Course',
        'Occasion' => 'Occasion',
        'Dish' => 'Dish',
        'Tag' => nil,
        'Diet' => 'Diet',
        'Genre' => 'Genre',
        'List' => 'List',
        'Ingredient' => 'Ingredient'
    }.each { |label, type|
      if tagstrings =
          if tagstring = findings.result_for(label)
            [ tagstring ]
          elsif tagstring = findings.result_for(label.pluralize)
            tagstring.split(',').map(&:strip)
          end
        ts ||= TaggingServices.new object
        tagstrings.each { |tagname|
          ts.tag_with tagname, User.super_id, {type: type}.compact
        }
      end
    }
=begin
    if author = findings.result_for('Author')
      ts ||= TaggingServices.new object
      ts.tag_with author, User.super_id, type: 'Author'
    end
    if course = findings.result_for('Course')
      ts ||= TaggingServices.new object
      ts.tag_with course, User.super_id, type: 'Course'
    end
    if occasion = findings.result_for('Occasion')
      ts ||= TaggingServices.new object
      ts.tag_with occasion, User.super_id, type: 'Occasion'
    end
    if tagstring = findings.result_for('Tags')
      ts ||= TaggingServices.new object
      tagstring.split(',').map(&:strip).each { |tagname| ts.tag_with tagname, User.super_id }
    end
    if tagstring = findings.result_for('Diet')
      ts ||= TaggingServices.new object
      tagstring.split(',').map(&:strip).each { |tagname| ts.tag_with tagname, User.super_id, type: Tag.typenum(:Diet) }
    end
    if tagstring = findings.result_for('Ingredients')
      ts ||= TaggingServices.new object
      tagstring.split(',').map(&:strip).each { |tagname| ts.tag_with tagname, User.super_id, type: 'Ingredient' }
    end
=end
  end

  # The robotags are those owned by super
  def robotags
    object.tags User.super_id
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def extract fieldname
    case fieldname.downcase
      when /_tags$/
        tagtype = fieldname.sub /_tags$/, ''
        tagtype = ['Culinary Term', 'Untyped'] if tagtype=='Other'
        strjoin visible_tags(:tagtype => tagtype).collect { |tag|
                  h.link_to_submit tag.name, tag, :mode => :modal, class: 'rcp_list_element_tag'
                }
      when /^tags$/
        h.list_tags_for_collectible visible_tags( :tagtype_x => [ :Question, :List ]), self
    when /^lists$/
        h.list_lists_with_status ListServices.associated_lists_with_status(self)
      when /^rcp/
        attrname = fieldname.sub(/^rcp/, '').downcase
        case attrname
          when 'picsafeurl'
            object.imgdata
          when 'titlelink'
            h.link_to object.title, object.url
          when 'video'
            (uri = URI(object.url)) &&
            uri.host.match(/\.youtube.com/) &&
            (vid = YouTubeAddy.extract_video_id(object.url)) &&
            "https://www.youtube.com/embed/#{vid}"
          else
            object.send(attrname.to_sym).to_s if object.respond_to? attrname
        end
      when /^comments/
        case fieldname.sub(/^comments_/, '')
          when 'mine'
          when 'friends'
          when 'others'
        end
      when 'site'
        h.link_to object.sourcename, object.sourcehome, class: 'tablink'
      when 'collections'
        strjoin object.collectors.collect { |user|
          h.link_to_submit( user.handle, h.user_path(user), :mode => :modal) unless user.current?
        }.compact
      when 'feeds'
        strjoin(object.feeds.where(approved: true).collect { |feed| h.link_to_submit feed.title, h.feed_path(feed) },'','',',', '<br>').html_safe
      when 'classname_lower'
        object.class.to_s.downcase
      else
        (method(fieldname.to_sym).call rescue nil) || ''
    end
  end

  # Collectibles are editable by default
  def read_only
    false
  end

  # Build an entity and its decorator based on type and ID of an existing object
  def self.build entity_type, entity_id
    entity_type.constantize.find(entity_id).decorate rescue nil
  end

  def image_class
    dom_id + '_pic'
  end

  # Get the user who first collected the recipe (or at least the one with the oldest Rcpref)
  def first_collector
    # find_by_id handles the NULL case (no User has in collection)
    User.find_by_id object.toucher_pointers.order('created_at ASC').limit(1).pluck(:user_id).first
  end

  # What types of tag are selectable for tagging the entity, i.e., pertain to the type of collectible we're talking about
  def eligible_tagtypes
    [ :Untyped, :Source, :Author, :CulinaryTerm ]
  end

  # Specify the types of tag that get displayed individually on the card. :Misc is a special "grab bag" type for all eligible types not shown individually
  def individual_tagtypes
    [ :Misc, :Source, :Author, :List ]
  end

  def editable_tagtypes
    individual_tagtypes - [ :List ]
  end

  # The types of tag that appear under the 'Misc. Tags' heading are the eligible ones, without those that are expressed individually
  def misc_tagtypes
    eligible_tagtypes - individual_tagtypes
  end

  def misc_tags_name_expanded misc_name
    # Translate from 'misc' to a sequence of type symbols for the Taggable class
    misc_name.sub '_misc_', '_' + misc_tagtypes.map { |type| Tag.typesym(type).to_s.downcase }.join('_') + '_'
  end

  # Here's where we define misc_tag_types, misc_tags_label, locked_misc_tags and editable_misc_tags
  def method_missing namesym, *args
    case (callname = namesym.to_s)
      when /^(\w*)_tag_types$/
        typesym = $1.capitalize.to_sym
        return typesym == :Misc ? Tag.typenum(misc_tagtypes) : Tag.typenum(typesym)
      when /^(\w*)_tags_label$/
        typesym = $1.capitalize.to_sym
        return typesym == :Misc ? 'Misc. Tag' : Tag.typename(typesym)
      when /^(locked|editable|visible)_misc_tag(_token)?s(=)?$/
        callname = misc_tags_name_expanded callname
    end
    super callname, *args
  end

  end
