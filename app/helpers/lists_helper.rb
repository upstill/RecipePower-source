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
      response_service.user.owned_lists[0..10].collect { |l|
        navlink "Add to '#{l.name.truncate(20)}'", pin_list_path(l), id: dom_id(l)
      }
    end

  end

  def list_menu_item l, entity, styling
    already_collected = ListServices.new(l).include? entity, User.current_or_guest.id
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

  # Describe all the lists and their statuses
  def list_lists_with_status lists_with_status
    safe_join lists_with_status.collect { |list_or_list_with_status|
      if list_or_list_with_status.is_a? Array
        list, status = list_or_list_with_status.first, list_or_list_with_status.last
      else
        list, status = list_or_list_with_status, nil
      end
      name = link_to_submit(list.name_tag.name.truncate(50).downcase, linkpath(list), :mode => :partial, :class => 'taglink' )
      name << " (#{homelink list.owner})".html_safe if list.owner_id != User.current_or_guest.id
      name << "--#{status}" if Rails.env.development? && status
      name
    }.compact, '&nbsp;<span class="tagsep">|</span> '.html_safe
  end

end
