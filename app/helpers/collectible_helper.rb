module CollectibleHelper

  def edit_collectible_link( label, entity, options={})
    options[:class] = "edit-collectible-link "+(options[:class] || "")
    if options.delete :template
      @templateer = Templateer.new entity
      link_to label, "#", options.merge(data: @templateer.data)
    else
      (options[:query] ||= {})[:modal] = true
      link_to_submit label, polymorphic_path(entity)+"/edit", options
    end
  end

  # Declare a button which either collects or edits an entity.
  # 'local' says to store the entity's data with the link (presuming the template is in the DOM)
  def collect_or_edit_button entity, local=false
    if entity.user_ids.include?(entity.collectible_user_id)
      edit_collectible_link "Edit", entity, class: "edit-collectible-link btn btn-default btn-xs", id: dom_id(entity)
    else
      url = polymorphic_path(entity)+"/collect"
      label = "Collect"
      link_to_submit label, url, class: "collect-collectible-link btn btn-default btn-xs", id: dom_id(entity)
    end
  end

  def collect_or_edit_button_replacement entity
    [ "a.collect-collectible-link##{dom_id entity}", collect_or_edit_button(entity) ]
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
