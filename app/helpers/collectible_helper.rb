module CollectibleHelper

  def button_styling styling, options={}
    styling.slice( :button_size ).merge options
  end

  def tag_link decorator, styling, options
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picurl picdata_with_fallback
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", "Tag it", styling, options.merge(:mode => :modal, :attribs => decorator.data(attribs))
  end

  def collection_link decorator, label, already_collected, styling, options={}
    query_options = { :styling => styling }
    query_options.merge! oust: true if already_collected
    url = polymorphic_path [:collect, decorator.object], query_options
    options[:method] = "POST"
    link_to_submit label, url, options
  end

  def collectible_tag_button decorator, styling, options={}
    options[:id] = dom_id(decorator)
    return "" unless current_user
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picurl picdata_with_fallback
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", "", styling, options.merge(class: "glyphicon glyphicon-tags", :mode => :modal, :attribs => decorator.data(attribs))
  end

  def collectible_edit_button entity, styling={}
    # Include the styling options in the link path as one parameter, then pass them to the button function
    url = polymorphic_path [:edit, entity], styling: styling
    button_to_submit '', url, styling.merge(class: "glyphicon glyphicon-edit", mode: :modal)
  end

  def collectible_share_button entity, options={}
    button_to_submit "", new_user_invitation_path(recipe_id: entity.id), options.merge(class: "glyphicon glyphicon-share", mode: :modal)
  end

  def collectible_list_button decorator, styling, options={}
    query = { }
    query[:access] = :all if response_service.admin_view?
    meth = method(decorator.klass.to_s.underscore.pluralize+"_path")
    button_to_submit "#{decorator.klass.to_s.pluralize} List", meth.call(query), button_styling(styling, options)
  end

  # Declare the voting buttons for a collectible
  def collectible_vote_buttons entity, styling={} # Style can be 'h', with more to come
    styling[:style] ||= "h"
    return "" unless
        (uplink = vote_link(entity, true, styling: styling)) &&
        (downlink = vote_link(entity, false, styling: styling))
    button_options = button_styling styling, method: "post", remote: true
    up_button = link_to_submit "", uplink, button_options.merge(class: vote_button_class(true, styling[:style]))
    down_button = link_to_submit "", downlink, button_options.merge(class: vote_button_class(false, styling[:style]))
    vote_counter = (entity.upvotes > 0 && entity.upvotes.to_s) || ""
    count = content_tag :span, vote_counter, class: vote_count_class(styling[:style])
    content_tag :div, (up_button+count+down_button).html_safe, class: vote_div_class(styling[:style]), id: dom_id(entity)
  end

  def vote_buttons_replacement entity
    [ "div.#{vote_div_class style}#"+dom_id(entity), collectible_vote_buttons(entity, params[:styling] || {}) ]
  end

  def collectible_buttons_panel decorator, styling={}, &block
    styling = params[:styling].merge styling if params[:styling]
    styling[:button_size] ||= "sm"  # Unless otherwise specified
    extras = block_given? ? with_output_buffer(&block) : ""
    with_format("html") do
      render("collectible/show_collectible_buttons", extras: extras, styling: styling, decorator: decorator, item: decorator.object)
    end
  end

  def collectible_buttons_panel_replacement decorator
    ["div.collectible-buttons##{dom_id decorator}", collectible_buttons_panel(decorator)]
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
