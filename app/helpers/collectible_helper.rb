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

end
