module CollectibleHelper

  def tag_link decorator, options
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picurl picdata_with_fallback
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", "Tag it", options.merge(:mode => :modal, :attribs => decorator.data(attribs))
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
    template_link decorator, "tag-collectible", "Tag", options.merge(:mode => :modal, :attribs => decorator.data(attribs))
  end

  def collectible_edit_button entity, options={}
    url = polymorphic_path(entity)+"/edit"
    button_to_submit 'Edit', url, options.merge(mode: :modal)
  end

  def collectible_share_button entity, options={}
    button_to_submit "Share", new_user_invitation_path(recipe_id: entity.id), options.merge(mode: :modal)
  end

  def collectible_list_button decorator, options={}
    meth = method(decorator.klass.to_s.underscore.pluralize+"_path")
    path = response_service.admin_view? ? meth.call(:access => :all) : meth.call
    button_to_submit "#{decorator.klass.to_s.pluralize} List", path, options
  end

  # Declare the voting buttons for a collectible
  def collectible_vote_button entity, options={} # Style can be 'h', with more to come
    style = options[:style] || "h"
    options = options.merge method: "post", remote: true
    return "" unless
        (uplink = vote_link(entity, true, style)) &&
        (downlink = vote_link(entity, false, style))
    up_button = link_to_submit "", uplink, options.merge(class: vote_button_class(true, style))
    down_button = link_to_submit "", downlink, options.merge(class: vote_button_class(false, style))
    vote_counter = (entity.upvotes > 0 && entity.upvotes.to_s) || ""
    count = content_tag :span, vote_counter, class: vote_count_class(style)
    content_tag :div, (up_button+count+down_button).html_safe, class: vote_div_class(style), id: dom_id(entity)
  end

  def vote_button_replacement entity, style="h"
    [ "div.#{vote_div_class style}#"+dom_id(entity), collectible_vote_button(entity, style: style) ]
  end

  def collectible_buttons_panel decorator, options={}, &block
    output = render("collectible/show_collectible_buttons", options.merge(decorator: decorator, item: decorator.object))
    output = with_output_buffer(&block) + output if block_given?
    content_tag :div, output.html_safe,
                class: "collectible-buttons",
                style: "display: inline-block",
                id: dom_id(decorator)
  end

  def collectible_buttons_panel_replacement decorator, options={}
    ["div.collectible-buttons##{dom_id decorator}", collectible_buttons_panel(decorator, options)]
  end

  def collectible_masonry_item decorator
    with_format("html") do
      render "show_masonry_item", item: decorator.object, decorator: decorator
    end
  end

  def collectible_masonry_item_replacement decorator, destroyed=false
    [".masonry-item-contents."+dom_id(decorator), (collectible_masonry_item(decorator) unless destroyed)]
  end

  def collectible_table_row decorator
    entity = decorator.object
    dir = entity.class.to_s.underscore.pluralize
    with_format("html") do
      render "index_table_row", item: entity, decorator: decorator
    end
  end

  def collectible_table_row_replacement decorator, destroyed=false
    ["tr##{decorator.dom_id}", (collectible_table_row(decorator) unless destroyed)]
  end

  # Return the followup after updating or destroying an entity: replace its pagelet with either an update, or the list of such entities
  def collectible_pagelet_followup entity, destroyed=false
    entity = entity.object if entity.is_a? Draper::Decorator
    {
        request: polymorphic_path((destroyed ? entity.class : entity), :mode => :partial),
        target: pagelet_body_selector(entity)
    }
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
      ExceptionNotification::Notifier.exception_notification(request.env, e, data: {message: content}).deliver
    end
    content_tag :div, link_to(content, decorator.url), options
  end

end
