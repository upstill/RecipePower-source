module CollectibleHelper

  # Render the set of collectible buttons
  def collectible_buttons_panel decorator, styling={}, &block
    except = styling.delete(:except) || []
    styling = params[:styling].merge styling if params[:styling]
    extras = block_given? ? yield : ""
    with_format("html") do
      render "collectible/collectible_buttons",
             extras: extras,
             except: except,
             styling: styling,
             decorator: decorator,
             item: decorator.object
    end
  end

  def collectible_taglist decorator
    taglist = decorator.object.tags.collect { |tag|
      link_to_submit(tag.name.downcase, tag, :mode => :modal, :class => "taglink" )
    }.join('&nbsp;<span class="tagsep">|</span> ')
    # <span class="<%= recipe_list_element_golink_class item %>">
    button = content_tag :div, collectible_tag_button(decorator, {}), class: "inline-glyphicon"
    (taglist+"&nbsp;"+button).html_safe
  end

  def collectible_buttons_panel_replacement decorator
    ["div.collectible-buttons##{dom_id decorator}", collectible_buttons_panel(decorator)]
  end

  def collectible_collect_icon_replacement decorator, size = nil, options={}
    [ "div.collectible-collect-icon.#{dom_id decorator}", collectible_collect_icon(decorator, size, options) ]
  end

  def collectible_collect_icon decorator, size = nil, options={}
    if size.is_a? Hash
      size, options = nil, size
    end
    if decorator.object.class == User
      glyph = user_follow_button decorator.object
    else
      glyph = if current_user_or_guest.has_in_collection? decorator.object
                sprite_glyph :check, size, title: 'In Collection'
              else
                collection_link decorator, sprite_glyph(:plus), {}, :in_collection => true
              end
    end
    content_tag :div, glyph, class: "collectible-collect-icon glyph-button #{dom_id decorator}"
  end

  def collectible_tools_menu_replacement decorator
    [ "div.tool-menu.#{dom_id(decorator)}", collectible_tools_menu(decorator) ]
  end

  def collectible_tools_menu decorator, size='lg', styling={}
    if size.is_a?(Hash)
      size, styling = 'lg', size
    end
    if user = current_user
      entity = decorator.object
      menu = hover_menu content_tag(:span, '', class: 'glyphicon glyphicon-cog'),
                        styling do
        in_collection = current_user.has_in_collection? decorator.object
        items = []

        items << collection_link(decorator,
                                 (in_collection ? 'Remove from Collection' : 'Add to Collection'), # checkbox_menu_item_label('Collection', in_collection),
                                 styling,
                                 :in_collection => !in_collection)

        items << link_to_submit('Lists',
                                polymorphic_path([:lists, entity]),
                                :mode => :modal,
                                :title => 'Manage lists on which this appears')

        if permitted_to? :update, entity.class.to_s.downcase.pluralize.to_sym
          url = polymorphic_path entity, :action => :edit, styling: styling
          items << link_to_submit('Edit', url, styling.merge(mode: :modal, title: nil))
        end

        if permitted_to? :delete, entity.class.to_s.downcase.pluralize
          items << button_to('Destroy',
                                  decorator.object_path,
                                  :method => :delete,
                                  confirm: "This will permanently remove ths #{decorator.human_name} from RecipePower for good: it can't be undone. Are you absolutely sure you want to do this?")

        end

        if entity.collectible_collected?
          privacy_label = checkbox_menu_item_label 'Private', entity.private
          items << collection_link(decorator, privacy_label, styling, private: !entity.private)
        end

        url = polymorphic_path [:editpic, entity], styling: styling
        items << link_to_submit('Get Picture', url, styling.merge(mode: :modal, title: 'Get Picture'))
      end
      content_tag :div, menu, class: "tool-menu #{dom_id(decorator)}"
    end
  end

  def button_styling styling, options={}
    styling.slice( :button_size ).merge options
  end

  def tag_link decorator, styling, options
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picuri imgdata
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", 'Tag it', styling, options.merge(:mode => :modal, :attribs => decorator.data(attribs))
  end

  def collection_link decorator, label, styling, query_options={}
    options = query_options.slice! :in_collection, :comment, :private
    query_options[:styling] = styling
    url = polymorphic_path [:collect, decorator.object], query_options
    options[:method] = 'PATCH'
    link_to_submit label, url, options.merge(title: 'Add to My Collection')
  end

  def collectible_tag_button decorator, styling, options={}
    options[:id] = dom_id(decorator)
    return "" unless current_user
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picuri imgdata
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator,
                  'tag-collectible',
                  sprite_glyph(:tag, 'xl'),
                  styling,
                  options.merge( :mode => :modal,
                                 :title => 'Tag Me',
                                 :attribs => decorator.data(attribs))
  end

  def collectible_edit_button entity, size=nil, styling={}
    entity = entity.object if entity.is_a? Draper::Decorator
    if permitted_to? :update, entity
      if size.is_a? Hash
        size, options = nil, size
      end
      url = polymorphic_path entity, :action => :edit, styling: styling
      button = button_to_submit '', url, 'glyph-edit-red', size, styling.merge(mode: :modal, title: 'Edit Me')
      content_tag :div, button, class: 'edit-button glyph-button'
    end
  end

  # Provide the button for uploading an image
  def collectible_upload_button entity, size=nil, styling={}
    entity = entity.object if entity.is_a? Draper::Decorator
    if permitted_to? :update, entity
      if size.is_a? Hash
        size, options = nil, size
      end
      url = polymorphic_path [:editpic, entity], styling: styling
      button = button_to_submit '', url, 'glyph-upload', size, styling.merge(mode: :modal, title: 'Get Picture')
      content_tag :div, button, class: 'upload-button glyph-button'
    end
  end

  # Define and return a share button for the collectible
  def collectible_share_button entity, size=nil, options={}
    if size.is_a? Hash
      size, options = nil, size
    end
    entity = entity.object if entity.is_a? Draper::Decorator
    button = button_to_submit '',
                              new_user_invitation_path(shared_type: entity.class.to_s, shared_id: entity.id),
                              'glyph-share',
                              size,
                              options.merge(mode: :modal, title: 'Share This')
    content_tag :div, button, class: 'share-button glyph-button'
  end

  def collectible_list_button decorator, options={}
    query = {}
    query[:access] = :all if response_service.admin_view?
    meth = method(decorator.klass.to_s.underscore.pluralize+"_path")
    button_to_submit "#{decorator.klass.to_s.pluralize} List", meth.call(query), options
  end

  # Declare the voting buttons for a collectible
  def collectible_vote_buttons entity
    uplink = vote_link(entity, true)
    downlink = vote_link(entity, false)
    button_options = { method: 'post', remote: true, class: 'vote-button'}
    vote_state = Vote.current entity
    up_button = button_to_submit '', uplink, 'glyph-vote-up', "xl", button_options.merge(title: 'Vote Up')
    down_button = button_to_submit '', downlink, 'glyph-vote-down', "xl", button_options.merge(title: 'Vote Down')
    vote_counter = (entity.upvotes > 0 && entity.upvotes.to_s) || ''
    upcount =
        content_tag(:span,
                    "#{entity.upvotes.to_s}<br>".html_safe,
                    class: 'vote-count') # if entity.upvotes > 0
    downcount =
        content_tag(:span,
                    "<br>#{entity.downvotes.to_s}".html_safe,
                    class: 'vote-count') # if entity.downvotes > 0
    left = content_tag :div, "#{upcount}#{up_button}".html_safe, class: 'vote-div'
    right = content_tag :div, "#{down_button}#{downcount}".html_safe, class: 'vote-div'
    content_tag :div, (left+right).html_safe, class: 'vote-buttons', id: dom_id(entity)
  end

  def vote_buttons_replacement entity
    [ "div.vote-buttons#"+dom_id(entity), collectible_vote_buttons(entity) ]
  end

end
