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
    entity = decorator.object
    hover_menu "Keep <span class='caret'></span>", styling do
      already_collected = entity.collected_by? current_user_or_guest_id
      cl = collection_link decorator,
                           checkbox_menu_item_label("Collection", already_collected),
                           already_collected,
                           styling,
                           :class => "checkbox-menu-item"
      [cl] +
          user.owned_lists.collect { |l|
            oust = true # l.includes? entity
            link_to_submit l.name.truncate(20),
                           pin_list_path(l,
                                         entity_type: (entity.klass.to_s rescue entity.class.to_s),
                                         entity_id: entity.id,
                                         oust: oust,
                                         styling: styling),
                           method: "POST",
                           id: dom_id(l),
                           mode: :partial,
                           class: "checkbox-menu-item"
          }
    end
  end

  def hover_menu label, options={}
    button = # "<a class='dropdown-toggle' data-toggle='dropdown'>+</a>".html_safe
      content_tag :button,
       label.html_safe,
       type: "button",
       class: "btn btn-default btn-#{options[:button_size] || 'xs'} dropdown-toggle",
       data: {toggle: "dropdown"},
       :"aria-expanded" => "false"
    list_items = yield.collect { |link| content_tag :li, link.html_safe }.join.html_safe
    list_tag = content_tag :ul, list_items, class: "dropdown-menu", role: "menu"
    content_tag :div, button+list_tag, class: "btn-group"
  end

end
