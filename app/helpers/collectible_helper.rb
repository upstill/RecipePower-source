module CollectibleHelper

  # Declare a button which either collects or edits an entity.
  def collect_or_tag_button entity, tag_only=false, options={}
    if tag_only.is_a?(Hash)
      tag_only, options = false, tag_only
    end
    options[:button_size] ||= "xs"
    options[:id] = dom_id(entity)
    return unless current_user
    if entity.collected_by?(current_user.id)
      attribs = %w( collectible_comment collectible_private collectible_user_id
                    element_id field_name human_name id object_path
                    tagdata tagging_user_id title )
      template_link entity, "tag-collectible", "Tag", options.merge( :mode => :modal, :attribs => attribs )
    elsif !tag_only # Either provide the Tag button or none
      url = polymorphic_path(entity)+"/collect"
      label = "Collect"
      options[:class] = "#{options[:class] || ''} collect-collectible-link"
      link_to_submit label, url, options
    end
  end

  def collect_or_tag_button_replacement entity, options={}
    [ "a.collect-collectible-link##{dom_id entity}", collect_or_tag_button(entity, options) ]
  end

  def collectible_masonry_item entity
    with_format("html") do render partial: "show_masonry_item" end
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

  def collectible_table_buttons entity, collect_or_tag=true, options={}
    if collect_or_tag.is_a? Hash
      collect_or_tag, options = true, collect_or_tag
    end
    typename = (entity.is_a?(Draper::Decorator) ? entity.object : entity).class.to_s.underscore
    typesym = typename.pluralize.to_sym
    btns = ""
    if block_given?
      btns << yield
    end
    permitted_to?(:tag, typesym) do
      btns << (
          tag(:br)+
          collect_or_tag_button(entity, options)
      ).html_safe
    end if collect_or_tag
    if response_service.admin_view? && permitted_to?(:destroy, typesym)
      btns << (
          tag(:br)+
          link_to_submit('Destroy', entity, options.merge(:button_style => "danger", :method => :delete, :confirm => 'Are you sure?'))
      ).html_safe
    end
    btns.html_safe
  end

  # Produce the standard buttons for display when showing the entity
  def collectible_action_buttons entity, context, editable=false
    result = collect_or_tag_button entity, button_size: "small"
    if editable
      url = polymorphic_path(entity)+"/edit"
      result << button_to_submit('Edit', url, mode: :modal)
    end
    if response_service.admin_view?
      typename = (entity.is_a?(Draper::Decorator) ? entity.object : entity).class.to_s.underscore.tr('_', ' ')
      confirm_msg = "This will remove the #{typename} from RecipePower and EVERY collection in which it appears. Are you sure this is appropriate?"
      result <<
        content_tag(
          :div,
          button_to("Destroy", polymorphic_path(entity), :form_class => "submit", :class => "btn btn-danger", :method => :delete, :confirm => confirm_msg ),
          style: "display: inline-block"
        )
    end
    result
    # button_to_submit 'Back to Lists', lists_path
    # <input class="btn btn-danger pull-left" type="submit" data-action="/recipes/1155" data-method="delete" value="Destroy" data-confirm="This will remove the Recipe from RecipePower and EVERY collection in which it appears. Are you sure this is appropriate?" clicked="true">
  end

end
