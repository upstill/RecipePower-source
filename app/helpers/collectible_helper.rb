module CollectibleHelper

  def edit_collectible_link( label, entity, options={})
    options[:class] = "edit-collectible-link #{'trigger ' if options[:trigger]}"+(options[:class] || "")
    if entity.is_a? Templateer
      # options[:class] << " run-template"
      link_to label, "#", options.merge(data: entity.data )
    else
      (options[:query] ||= {})[:modal] = true
      link_to_submit label, polymorphic_path(entity)+"/edit", options
    end
  end

  # Declare a button which either collects or edits an entity.
  def collect_or_edit_button entity, trigger=false
    if entity.user_ids.include?(entity.collectible_user_id)
      edit_collectible_link "Edit", entity, class: "btn btn-default btn-xs ", id: dom_id(entity), trigger: trigger
    else
      url = polymorphic_path(entity)+"/collect"
      label = "Collect"
      link_to_submit label, url, class: "collect-collectible-link btn btn-default btn-xs", id: dom_id(entity)
    end
  end

  def collect_or_edit_button_replacement entity, trigger=false
    [ "a.collect-collectible-link##{dom_id entity}", collect_or_edit_button(entity, trigger) ]
  end

  def collectible_masonry_item entity
    with_format("html") do render_to_string partial: "show_masonry_item" end
  end

  def collectible_masonry_item_replacement entity, destroyed=false
    [ ".masonry-item-contents."+dom_id(entity), (collectible_masonry_item(entity) unless destroyed) ]
  end

  def collectible_smallpic entity
    with_format("html") do render_to_string partial: "shared/recipe_smallpic" end
  end

  def collectible_smallpic_replacement entity, destroyed=false
    [ "."+recipe_list_element_class(@recipe), (collectible_smallpic(entity) unless destroyed) ]
  end

end
