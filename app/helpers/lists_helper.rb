module ListsHelper

  def list_homelink list, options={}
    name = list.name
    name = name.truncate(options[:truncate]) if options[:truncate]
    (data = (options[:data] || {}))[:report] = polymorphic_path [:touch, list]
    klass = "#{options[:class]} entity list"
    path = case action = (options.extract!(:action)[:action] || :contents)
             when :show
               list_path list
             else
               polymorphic_path([action, list])
           end
    link_to_submit name, path, {:mode => :partial}.merge(options).merge(data).merge(class: klass).except(:action)
  end

  # Provide a button for adding (pinning) an entity to the list
  def pin_button list, entity
    button_to_submit list.name,
                     pin_list_path(list),
                     method: "POST",
                     query: { entity_type: (entity.klass.to_s rescue entity.class.to_s), entity_id: entity.id }
  end

  def pin_navmenu entity
    navtab :pin, "+", users_path do
      response_service.user.owned_lists[0..10].collect { |l|
        navlink "Add to '#{l.name.truncate(20)}'", pin_list_path(l), id: dom_id(l)
      }
    end

  end

=begin
  # Offer to let the user save the item in their collection and any list they own, plus a new list
  # NB Obsolete: now supplanted by list-manager dialog
  def collectible_list_menu decorator, user, styling, options={}
    if user
      entity = decorator.object
      hover_menu sprite_glyph(:"list-add"), styling.merge(class: dom_id(decorator)) do
        already_collected = entity.collectible_collected? current_user_or_guest_id
        cl = collection_link decorator,
                             checkbox_menu_item_label("Collection", already_collected),
                             styling,
                             :in_collection => !already_collected,
                             :class => "checkbox-menu-item collection"
        [ content_tag(:li, cl),
          user.owned_lists.collect { |l| content_tag :li, (list_menu_item l, entity, styling.merge(class: dom_id(l))) },
          "<hr class='menu'>".html_safe,
          content_tag(:li,
                      link_to_submit("Start a List...",
                                     new_list_path(entity_type: entity.class.to_s, entity_id: entity.id),
                                     mode: :modal,
                                     class: "transient"))
        ].flatten
      end
    else
      link_to_submit "",
                     new_user_registration_path(flash: { alert: "You can collect things and make lists once you're logged in"},
                                                header: "Join RecipePower"),
                     styling.merge( class: "glyphicon glyphicon-pushpin" )
    end
  end
=end

  def list_menu_item l, entity, styling
    already_collected = ListServices.new(l).include? entity, current_user_or_guest_id
    link_to_submit checkbox_menu_item_label(l.name.truncate(20), already_collected),
                   pin_list_path(l,
                        entity_type: (entity.klass.to_s rescue entity.class.to_s),
                        entity_id: entity.id,
                        oust: already_collected,
                        styling: styling),
                   method: "POST",
                   class: "checkbox-menu-item #{dom_id(l)}"
  end

  def list_menu_item_replacement list, entity, styling
    [ "ul.#{dom_id entity} a.checkbox-menu-item.#{dom_id list}", list_menu_item(list, entity, styling) ]
  end

  def hover_menu label, options={}
    return with_format('html') { render 'shared/hover_menu',
                                        label: label,
                                        klass: options[:class] || '',
                                        links: yield }
  end

end
