module ListsHelper

  # Provide a button for adding (pinning) an entity to the list
  def pin_button list, entity
    button_to_submit list.name,
                     pin_list_path(list),
                     method: "POST",
                     query: { entity_type: (entity.klass.to_s rescue entity.class.to_s), entity_id: entity.id }
  end

  def pin_navmenu entity
    navtab :pin, "+", users_path do
      @user.owned_lists[0..10].collect { |l|
        navlink "Add to '#{l.name.truncate(20)}'", pin_list_path(l), id: dom_id(l)
=begin
        link_to_submit "Add to '#{l.name.truncate(20)}'",
                       pin_list_path(l),
                       method: "POST",
                       id: dom_id(l),
                       query: { entity_type: (entity.klass.to_s rescue entity.class.to_s), entity_id: entity.id },
                       :mode => :partial
=end
      }
    end

  end

  # Offer to let the user save the item in their collection and any list they own, plus a new list
  def pin_menu decorator, user, styling, options={}
    if user
      entity = decorator.object
      hover_menu "", styling do
        already_collected = entity.collected? current_user_or_guest_id
        cl = collection_link decorator,
                             checkbox_menu_item_label("Collection", already_collected),
                             already_collected,
                             styling,
                             :class => "checkbox-menu-item"
        [ content_tag(:li, cl),
          user.owned_lists.collect { |l| content_tag :li, (list_menu_item l, entity, styling) },
          "<hr class='menu'>".html_safe,
          content_tag(:li,
                      link_to_submit("Start a List...",
                                     new_list_path(entity_type: entity.class.to_s, entity_id: entity.id),
                                     mode: :modal,
                                     class: "transient"))
        ].flatten
      end
    else
      x=2 # TODO: Give user a chance to set up an account
    end
  end

  def list_menu_item l, entity, styling
    already_collected = ListServices.new(l).include? entity, current_user_or_guest_id
    link_to_submit checkbox_menu_item_label(l.name.truncate(20), already_collected),
                   pin_list_path(l,
                                 entity_type: (entity.klass.to_s rescue entity.class.to_s),
                                 entity_id: entity.id,
                                 oust: already_collected,
                                 styling: styling),
                   method: "POST",
                   id: dom_id(l),
                   mode: :partial,
                   class: "checkbox-menu-item"
  end

  def list_menu_item_replacement list, entity, styling
    [ "div.collectible-buttons##{dom_id entity} a.checkbox-menu-item##{dom_id list}", list_menu_item(list, entity, styling) ]
  end

  def hover_menu label, options={}
    button = # "<a class='dropdown-toggle' data-toggle='dropdown'>+</a>".html_safe
      content_tag :button,
       label.html_safe,
       type: "button",
       class: "btn btn-default btn-#{options[:button_size] || 'xs'} dropdown-toggle glyphicon glyphicon-pushpin",
       data: { toggle: "dropdown" },
       :"aria-expanded" => "false"
    list_items = yield.join.html_safe
    list_tag = content_tag :ul, list_items, class: "dropdown-menu", role: "menu"
    content_tag :div, button+list_tag, class: "btn-group"
  end

  # Provide a replacement item for removing the item from a list
  def list_stream_item_deleter list, entity
    collectible_stream_item_deleter dom_id(list), entity
  end

end
