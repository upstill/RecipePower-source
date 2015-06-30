module CollectibleHelper

  # Render the set of collectible buttons
  def collectible_buttons_panel decorator, styling={}, &block
    styling = params[:styling].merge styling if params[:styling]
    styling[:button_size] ||= "sm"  # Unless otherwise specified
    extras = block_given? ? yield : ""
    with_format("html") do
      render("collectible/collectible_buttons", extras: extras, styling: styling, decorator: decorator, item: decorator.object)
    end
  end

  def collectible_taglist decorator
    taglist = decorator.object.tags.collect { |tag|
      link_to_submit(tag.name.downcase, tag, :mode => :modal, :class => "taglink" )
    }.join('&nbsp;<span class="tagsep">|</span> ')
    # <span class="<%= recipe_list_element_golink_class item %>">
    button = content_tag :div, collectible_tag_button(decorator, {}), class: "inline-glyphicon"
    (taglist+"&nbsp;"+button).html_safe
  end

  def collectible_buttons_panel_replacement decorator
    ["div.collectible-buttons##{dom_id decorator}", collectible_buttons_panel(decorator)]
  end

  def collectible_collect_icon decorator, size = nil, options={}
    if size.is_a? Hash
      size, options = nil, size
    end
    if current_user_or_guest.collected?(decorator.object)
      sprite_glyph :check, size
    else
      link_to_submit sprite_glyph(:plus, size), polymorphic_path([:collect, decorator.object]), options
    end
  end

  def button_styling styling, options={}
    styling.slice( :button_size ).merge options
  end

  def tag_link decorator, styling, options
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picuri imgdata
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", "Tag it", styling, options.merge(:mode => :modal, :attribs => decorator.data(attribs))
  end

  def collection_link decorator, label, already_collected, styling, options={}
    query_options = { :styling => styling }
    query_options.merge! oust: true if already_collected
    url = polymorphic_path [:collect, decorator.object], query_options
    options[:method] = "PATCH"
    link_to_submit label, url, options
  end

  def collectible_tag_button decorator, styling, options={}
    options[:id] = dom_id(decorator)
    return "" unless current_user
    attribs = %w( collectible_comment collectible_private collectible_user_id
                    id title url picuri imgdata
                    element_id field_name human_name object_path tag_path
                    tagging_tag_data tagging_user_id )
    template_link decorator, "tag-collectible", sprite_glyph(:tag, "xl"), styling, options.merge(:mode => :modal, :attribs => decorator.data(attribs))
  end

  def collectible_edit_button entity, styling={}
    return unless permitted_to? :update, entity
    url = polymorphic_path entity, :action => :edit, styling: styling
    button = button_to_submit sprite_glyph("edit-red"), url, styling.merge(mode: :modal)
    content_tag :div, button, class: "edit-button"
  end

  # Define and return a share button for the collectible
  def collectible_share_button entity, size=nil, options={}
    if size.is_a? Hash
      size, options = nil, size
    end
    entity = entity.object if entity.is_a? Draper::Decorator
    button = button_to_submit "", new_user_invitation_path(shared_type: entity.class.to_s, shared_id: entity.id), "glyph-share", size, options.merge(mode: :modal)
    content_tag :div, button, class: "share-button"
  end

  def collectible_list_button decorator, options={}
    query = {}
    query[:access] = :all if response_service.admin_view?
    meth = method(decorator.klass.to_s.underscore.pluralize+"_path")
    button_to_submit "#{decorator.klass.to_s.pluralize} List", meth.call(query), options
  end

  # Declare the voting buttons for a collectible
  def collectible_vote_buttons entity
    uplink = vote_link(entity, true)
    downlink = vote_link(entity, false)
    button_options = { method: "post", remote: true, class: "vote-button" }
    vote_state = Vote.current entity
    up_button = button_to_submit "", uplink, "glyph-vote-up", "xl", button_options
    down_button = button_to_submit "", downlink, "glyph-vote-down", "xl", button_options
    vote_counter = (entity.upvotes > 0 && entity.upvotes.to_s) || ""
    upcount =
        content_tag(:span,
                    "#{entity.upvotes.to_s}<br>".html_safe,
                    class: "vote-count") # if entity.upvotes > 0
    downcount =
        content_tag(:span,
                    "<br>#{entity.downvotes.to_s}".html_safe,
                    class: "vote-count") # if entity.downvotes > 0
    left = content_tag :div, "#{upcount}#{up_button}".html_safe, class: "vote-div"
    right = content_tag :div, "#{down_button}#{downcount}".html_safe, class: "vote-div"
    content_tag :div, (left+right).html_safe, class: "vote-buttons", id: dom_id(entity)
  end

  def vote_buttons_replacement entity
    [ "div.vote-buttons#"+dom_id(entity), collectible_vote_buttons(entity) ]
  end

  # Sort out a suitable URL to stuff into an image thumbnail for a recipe, enclosing it in a div
  # of the class given in options. The image will stretch either horizontally (fill_mode: "fixed-height")
  # or vertically (fill_mode: "fixed-width") within the dimensions given by the enclosing div.
  def safe_image_div decorator, fallback=:site, options = {}
    if fallback.is_a? Hash
      fallback, options = :site, fallback
    end
    fill_mode = options.delete(:fill_mode) || "fixed-width"
    begin
      return if (url = decorator.imgdata(fallback)).blank?
      content = image_with_error_recovery url,
                                          alt: "Image Not Accessible",
                                          id: (dom_id decorator),
                                          class: fill_mode
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

    style = case fill_mode
              when "fixed-width"
                "width: 100%; height: auto;"
              when "fixed-height"
                "width: auto; height: 100%;"
            end
    options[:style] = style if style
    content_tag :div, link_to(content, decorator.url), options
  end

end
