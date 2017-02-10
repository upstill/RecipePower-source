class CollectibleDecorator < Draper::Decorator
  include Templateer
  delegate_all

  # Translation from label names to attribute names
  def attribute_for what
    what.to_s.downcase.to_sym
  end

  # sample_page is a full URL somewhere on the associated site so we can absolutize links
  def sample_page

  end

  def picurl
    picurl = object.imglink
    (picurl.present? && sample_page) ? valid_url(picurl, sample_page) : picurl
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

  def attribute_name_for label
    case label
      when 'Title'
        'title'
      when 'Description'
        'description'
    end
  end

  # Process the results of a gleaning
  def assert_gleaning gleaning
    gleaning.extract1 'Title' do |value| self.title = value end
    gleaning.extract1 'Image' do |value| self.image = value end
    gleaning.extract1 'Description' do |value| self.description = value end
  end

  # Here's where we incorporate findings from a page into the corresponding entity
  def findings= findings
    self.title = findings.result_for('Title') if findings.result_for('Title').present?
    self.description = findings.result_for('Description') if findings.result_for('Description').present? && description.blank?
    ts = nil # TaggingService object
    if self.is_a? Recipe
      self.prep_time = findings.result_for('Prep Time') if findings.result_for('Prep Time').present?
      self.cook_time = findings.result_for('Cooking Time') if findings.result_for('Cooking Time').present?
      if findings.result_for('Total Time').present?
        tt = Tag.assert (self.total_time = findings.result_for('Total Time')), :tagtype => :Time
        tt && ((ts ||= TaggingServices.new object).tag_with tt, User.super_id)
      end
      self.yield = findings.result_for('Yield') if findings.result_for('Yield').present?
    end
    if findings.result_for('Image').present? && self.image.blank?
      self.image = findings.result_for('Image')
      image_changed = image.present?
    end
    save if id.nil? || changed? || image_changed # No other extractions need apply until saved
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

  # When attributes are selected directly and returned as gleaning attributes, assert them into the model
  def assert_gleaning_attribute label, value
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
  def arity fieldname
    case fieldname.downcase
      when /_tags$/
        tagtype = fieldname.sub /_tags$/, ''
        tagtype = ['Culinary Term', 'Untyped'] if tagtype=='Other'
        visible_tags(:tagtype => tagtype).count
      when 'list', 'lists'
        ListServices.associated_lists(object).count # ListServices.find_by_listee(object).count
    end
  end

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
=begin
      when 'list', 'lists'
        strjoin ListServices.find_by_listee(object).collect { |list|
                  llink = h.link_to_submit list.name, list, class: 'rcp_list_element_tag'
                  if list.owner_id == object.tagging_user_id
                    llink
                  else
                    ulink = h.link_to list.owner.handle, list.owner, class: 'rcp_list_element_tag'
                    "#{llink} (#{ulink})".html_safe
                  end
                }
=end
      when 'collections'
        strjoin CollectibleServices.new(object).collectors.collect { |user|
          h.link_to_submit( user.handle, h.user_path(user), :mode => :modal) unless user.id == object.tagging_user_id
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
