module CollectibleHelper

  # List of buttons in the panel
  def collectible_buttons_available
    # Used to be (before edit_button absorbed all the rest): %w{ edit_button lists_button tools_menu tag_button share_button upload_button collect_button}
    %w{ edit_button share_button upload_button collect_button}
  end

  # Styling hash asserting all buttons
  def collectible_buttons_all
    h = {}
    collectible_buttons_available.each { |name| h[name.to_sym] = true }
    h
  end

  # Render the set of collectible buttons
  def collectible_buttons_panel decorator, size=nil, styling={}, &block
    if size.is_a? Hash
      size, styling = nil, size
    end

    styling = params[:styling] ? params[:styling].merge(styling) : styling.clone
    spanclass = recipe_list_element_golink_class decorator.object

    button_list = collectible_buttons_available.keep_if { |which_button|
      styling.delete(which_button) || styling.delete(which_button.to_sym)
    }.collect { |which_button|
      content_tag :span,
                  method("collectible_#{which_button}").call(decorator, size, styling),
                  class: spanclass
    }.join(' ')

    content_tag :div,
                "#{yield if block_given?} #{button_list}".html_safe,
                class: 'collectible-buttons',
                style: 'display: inline-block',
                id: dom_id(decorator)
  end

  def collectible_buttons_panel_replacement decorator
    ["div.collectible-buttons##{dom_id decorator}", collectible_buttons_panel(decorator)]
  end

  ################## Standardized glyph buttons for collectibles ##########################
  def collectible_edit_button decorator, size=nil, styling={}
    entity = decorator.object
    if permitted_to? :update, entity
      if size.is_a? Hash
        size, styling = nil, size
      end
      button = button_to_submit styling.delete(:label),
                                polymorphic_path([:edit, entity], styling: styling),
                                'glyph-edit-red',
                                size,
                                styling.merge(mode: :modal, title: 'Edit Me')
      # content_tag :div, button, class: 'edit-button glyph-button'
    end
  end

  def collectible_lists_button decorator, size=nil, options={}
    entity = decorator.object
    if permitted_to? :lists, entity
      if size.is_a? Hash
        size, styling = nil, size
      end
      button = button_to_submit options.delete(:label),
                                polymorphic_path([:lists, entity], :mode => :modal),
                                'glyph-list-add',
                                size,
                                :title => 'Manage treasuries on which this appears'
      # content_tag :div, button, class: 'lists-button glyph-button'
    end
  end

  def collectible_tools_menu decorator, size=nil, styling={}
    if size.is_a?(Hash)
      size, styling = nil, size
    end
    if user = current_user
      entity = decorator.object
      menu = hover_menu content_tag(:span, '', class: 'glyphicon glyphicon-cog'),
                        styling do
        items = []

        items << collectible_collect_button(decorator, size, styling.merge(label: true, removable: true))

        items << collectible_edit_button(decorator, size, styling.merge(label: 'Edit'))

        items << collectible_lists_button(decorator, size, styling.merge(label: 'Treasuries'))

        if entity.collectible_collected?
          privacy_label = checkbox_menu_item_label 'Private', entity.private
          items << collection_link(decorator,
                                   privacy_label,
                                   styling,
                                   private: !entity.private,
                                   title: entity.private ? 'Reveal to Others' : 'Hide from Others')
        end

        items << collectible_editpic_button(decorator, size, styling.merge(label: 'Get Picture'))

        items << collectible_destroy_button(decorator, 'xs', styling.merge(title: 'The Nuclear Option', style: 'margin-left: 3.8em;'))
      end
      content_tag :div, menu, class: "tool-menu #{dom_id(decorator)}"
    end
  end

  def collectible_tools_menu_replacement decorator
    [ "div.tool-menu.#{dom_id(decorator)}", collectible_tools_menu(decorator) ]
  end

  def collectible_tag_button decorator, size=nil, options={}
    if size.is_a? Hash
      size, options = nil, size
    end
    options[:id] = dom_id(decorator)
    return '' unless current_user
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picuri imgdata
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator,
                  'tag-collectible',
                  sprite_glyph(:tag, size),
                  {},
                  options.merge( :mode => :modal,
                                 :title => 'Tag Me',
                                 :attribs => decorator.data(attribs))
  end

  # Define and return a share button for the collectible
  def collectible_share_button decorator, size=nil, options={}
    if current_user
      if size.is_a? Hash
        size, options = nil, size
      end
      entity = decorator.object
      button = button_to_submit '',
                                new_user_invitation_path(shared_type: entity.class.to_s, shared_id: entity.id),
                                'glyph-share',
                                size,
                                options.merge(mode: :modal, title: 'Share This')
      content_tag :div, button, class: 'share-button glyph-button'
    end
  end

  # Provide the button for uploading an image
  def collectible_editpic_button entity, size=nil, styling={}
    entity = entity.object if entity.is_a? Draper::Decorator
    if permitted_to? :update, entity
      if size.is_a? Hash
        size, options = nil, size
      end
      button = button_to_submit styling.delete(:label),
                                polymorphic_path( [:editpic, entity], styling: styling),
                                'glyph-upload',
                                size,
                                styling.merge(mode: :modal, title: 'Get Picture')
      # content_tag :div, button, class: 'upload-button glyph-button'
    end
  end

  def collectible_collect_button decorator, size = nil, options={}
    if current_user
      if size.is_a? Hash
        size, options = nil, size
      end
      entity = decorator.object
      if entity.class == User
        user_follow_button entity, size, options
      else
        do_label = options.delete :label
        label = ''
        if current_user_or_guest.has_in_collection? entity
          if options[:removable]
            label = '&nbsp;Remove from Collection' if do_label
            collection_link decorator, sprite_glyph(:minus)+label.html_safe, {}, :in_collection => false
          else
            label = '&nbsp;In Collection' if do_label
            content_tag :span,
                        sprite_glyph(:check, size, title: 'In Collection') + label.html_safe,
                        class: "collection-state #{dom_id decorator.object}"
          end
        else
          label = '&nbsp;Add to Collection' if do_label
          collection_link decorator, sprite_glyph(:plus)+label.html_safe, {}, :in_collection => true
        end
      end
      # content_tag :div, glyph, class: "collectible-collect-icon glyph-button #{dom_id decorator}"
    end
  end

  def collectible_collect_button_replacement decorator, size = nil, options={}
    [ ".collection-state.#{dom_id decorator}", collectible_collect_button(decorator, size, options) ]
  end

  def collectible_destroy_button decorator, size = nil, options={}
    if response_service.admin_view?
      begin
        # Throw an exception if there's no :delete action
        Rails.application.routes.recognize_path(decorator.object_path, method: :delete)
        # Include the Destroy button iff there's a destroy action
        button_to_submit (options.delete(:label) || "Destroy this #{decorator.human_name}"),
                         decorator.object_path,
                         {
                             button_style: :danger,
                             button_size: (size || 'sm'),
                             method: :delete,
                             title: 'The nuclear option',
                             # confirm_msg: 'Ultimate, permanent destruction, right? Confirm please.',
                             with_form: true,
                             wait_msg: "Deleting \"#{decorator.title}\"...",
                             confirm_msg: "This will permanently remove ths #{decorator.human_name} from RecipePower for good: it can't be undone. Are you absolutely sure you want to do this?"
                         }.merge(options)
      rescue
      end
    end
  end

  ################## End of standardized buttons ##########################

  def collectible_source decorator, options={}
    if decorator.object.class == Feed
      feed_entries_status decorator.object
    elsif decorator.object.class == List
      'compiled by '.html_safe + homelink(decorator.object.owner, options)
    elsif (decorator.object.respond_to?(:site) && decorator.object.site)
      'source: '.html_safe + homelink(decorator.object.site, options)
    end
  end

  # Provide a list of the tags attached to the collectible, ending with the tagging button
  def collectible_taglist decorator
    taglist = decorator.object.tags.collect { |tag|
      link_to_submit(tag.name.downcase, tag, :mode => :modal, :class => 'taglink')
    }.join '&nbsp;<span class="tagsep">|</span> '
    button = content_tag :div, collectible_tag_button(decorator), class: 'inline-glyphicon'
    (taglist+'&nbsp;'+button).html_safe
  end

  def collection_link decorator, label, styling, query_options={}
    options = query_options.slice! :in_collection, :comment, :private
    query_options[:styling] = styling
    link_to_submit label,
                   polymorphic_path([:collect, decorator.object], query_options),
                   {title: 'Add to My Collection'}.
                       merge(options).
                       merge(method: 'PATCH',
                             class: "collection-state #{dom_id decorator}")
  end

  # Declare the voting buttons for a collectible
  def collectible_vote_buttons entity, options={}
    if entity.is_a? Collectible
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
      content_tag :div, (left+right).html_safe, class: "#{options[:class]} vote-buttons", id: dom_id(entity)
    end
  end

  def vote_buttons_replacement entity
    [ "div.vote-buttons#"+dom_id(entity), collectible_vote_buttons(entity, class: 'stamp votes') ]
  end

end
