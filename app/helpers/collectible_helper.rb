module CollectibleHelper

  def tag_link decorator, options
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picurl picdata_with_fallback
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", "Tag it", options.merge( :mode => :modal, :attribs => decorator.data(attribs) )
  end

  def collection_link decorator, label, already_collected, options={}
    url = polymorphic_path(decorator.object)+"/collect"
    url = assert_query(url, oust: true) if already_collected
    options[:method] = "POST"
    link_to_submit label, url, options
  end

  def collectible_tag_button decorator, options
    options[:button_size] ||= "xs"
    options[:id] = dom_id(decorator)
    return "" unless current_user
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picurl picdata_with_fallback
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", "Tag", options.merge( :mode => :modal, :attribs => decorator.data(attribs) )
  end

  # Declare a button which either collects or edits an entity.
  def collect_or_tag_button decorator, collect_or_tag=:both, options={}
    if collect_or_tag.is_a?(Hash)
      collect_or_tag, options = :both, collect_or_tag
    end
    options[:button_size] ||= "xs"
    options[:id] = dom_id(decorator)
    options[:class] = "#{options[:class] || ''} collect-collectible-link"
    return "" unless current_user
    if decorator.collected_by?(current_user.id)
      collectible_tag_button decorator, options
    elsif (collect_or_tag != :tag_only) # Either provide the Tag button or none
      collection_link decorator, "Grab It", false, options
    else
      ""
    end
  end

  def collectible_buttons_panel decorator, options={}
    render "show_collectible_buttons", options.merge( decorator: decorator, item: decorator.object )
  end

  def collectible_buttons_panel_replacement decorator, options={}
    [ "div.collectible-buttons##{dom_id decorator}", collectible_buttons_panel(decorator, options) ]
  end

  def collect_or_tag_button_replacement decorator, options={}
    [ "a.collect-collectible-link##{dom_id decorator}", collect_or_tag_button(decorator, options) ]
  end

  def collectible_masonry_item decorator
    with_format("html") do render "show_masonry_item", item: decorator.object, decorator: decorator end
  end

  def collectible_masonry_item_replacement decorator, destroyed=false
    [ ".masonry-item-contents."+dom_id(decorator), (collectible_masonry_item(decorator) unless destroyed) ]
  end

  def collectible_table_row decorator
    entity = decorator.object
    dir = entity.class.to_s.underscore.pluralize
    with_format("html") do render "index_table_row", item: entity, decorator: decorator end
  end

  def collectible_table_row_replacement decorator, destroyed=false
    [ "tr##{decorator.dom_id}", (collectible_table_row(decorator) unless destroyed) ]
  end

  # Return the followup after updating or destroying an entity: replace its pagelet with either an update, or the list of such entities
  def collectible_pagelet_followup entity, destroyed=false
    entity = entity.object if entity.is_a? Draper::Decorator
    {
        request: polymorphic_path((destroyed ? entity.class : entity), :mode => :partial),
        target: pagelet_body_selector(entity)
    }
  end

  # Provide the standard buttons for a collectible entity: Collect/Tag and (for admins) Destroy
  def collectible_buttons decorator, collect_or_tag=:both, options={}
    if collect_or_tag.is_a? Hash
      collect_or_tag, options = :both, collect_or_tag
    end
    entity = decorator.object
    typename = entity.class.to_s.underscore
    typesym = typename.pluralize.to_sym
    btns = ""
    if block_given?
      btns << yield
    end
    permitted_to?(:tag, typesym) do
      btns << collect_or_tag_button(decorator, collect_or_tag, options)
    end if :collect_or_tag && (:collect_or_tag != :neither)
    if response_service.admin_view? && permitted_to?(:destroy, typesym)
      btns << link_to_submit('Destroy', entity, options.merge(:button_style => "danger", :method => :delete, :confirm => 'Are you sure?'))
    end
    btns.html_safe
  end

  # Produce the standard buttons for display when showing the entity
  def collectible_action_buttons decorator, context, editable=false
    entity = decorator.object
    if editable
      url = polymorphic_path(entity)+"/edit"
      result = button_to_submit('Edit', url, mode: :modal)
    else
      result = collect_or_tag_button decorator, button_size: "small"
    end
    if response_service.admin_view?
      typename = entity.class.to_s.underscore.tr('_', ' ')
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

  # Sort out a suitable URL to stuff into an image thumbnail for a recipe
  def safe_image_div decorator, options = {}
    begin
      return if (url = decorator.picdata).blank?
      # options.merge!( class: "stuffypic", data: { fillmode: "width" } ) # unless url =~ /^data:/
      content = image_with_error_recovery url,
                                          alt: "Image Not Accessible",
                                          id: (dom_id decorator),
                                          style: "width:100%; height:auto;"
    rescue Exception => e
      if url
        url = "data URL" if url =~ /^data:/
      else
        url = "nil URL"
      end
      content =
          "Error rendering image #{url.truncate(255)} from "+ (decorator ? "#{decorator.human_name} #{decorator.id}: '#{decorator.title}'" : "null #{decorator.human_name}")
      ExceptionNotification::Notifier.exception_notification(request.env, e, data: { message: content}).deliver
    end
    content_tag :div, link_to(content, decorator.url), options
  end

end
