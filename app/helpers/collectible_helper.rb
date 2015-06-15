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
    template_link decorator, "tag-collectible", "", styling, options.merge(class: "glyphicon glyphicon-tags", :mode => :modal, :attribs => decorator.data(attribs))
  end

  def collectible_edit_button entity, styling={}
    # Include the styling options in the link path as one parameter, then pass them to the button function
    if permitted_to? :update, entity
      url = polymorphic_path entity, :action => :edit, styling: styling
      button_to_submit '', url, styling.merge(class: "glyphicon glyphicon-pencil", mode: :modal)
    end
  end

  def collectible_share_button entity, options={}
    entity = entity.object if entity.is_a? Draper::Decorator
    button_to_submit "", new_user_invitation_path(shared_type: entity.class.to_s, shared_id: entity.id), options.merge(class: "glyphicon glyphicon-share", mode: :modal)
  end

  def collectible_list_button decorator, styling, options={}
    query = { }
    query[:access] = :all if response_service.admin_view?
    meth = method(decorator.klass.to_s.underscore.pluralize+"_path")
    button_to_submit "#{decorator.klass.to_s.pluralize} List", meth.call(query), button_styling(styling, options)
  end

  # Declare the voting buttons for a collectible
  def collectible_vote_buttons entity, styling={} # Style can be 'h' or 'bold', with more to come
    styling[:style] ||= "h"
    uplink = vote_link(entity, true, styling: styling)
    downlink = vote_link(entity, false, styling: styling)
    button_options = button_styling styling, method: "post", remote: true
    vote_state = Vote.current entity
    up_button = link_to_submit "", uplink, button_options.merge(class: vote_button_class(:up, vote_state, styling[:style]))
    down_button = link_to_submit "", downlink, button_options.merge(class: vote_button_class(:down, vote_state, styling[:style]))
    vote_counter = (entity.upvotes > 0 && entity.upvotes.to_s) || ""
    count = content_tag :span, vote_counter, class: vote_count_class(styling[:style])
    upcount =
        content_tag(:span,
                    "#{entity.upvotes.to_s}<br>",
                    class: vote_count_class(styling[:style])) if entity.upvotes > 0
    downcount =
        content_tag(:span,
                    "#{entity.downvotes.to_s}<br>",
                    class: vote_count_class(styling[:style])) if entity.downvotes > 0
    left = content_tag :div, "#{upcount}#{up_button}".html_safe, class: "vote-div"
    right = content_tag :div, "#{down_button}#{downcount}".html_safe, class: "vote-div"
    content_tag :div, (left+right).html_safe, class: vote_div_class(styling[:style]), id: dom_id(entity)
  end

  def vote_buttons_replacement entity
    styling = params[:styling] || {}
    styling[:style] ||= "h"
    [ "div.#{vote_div_class styling[:style]}#"+dom_id(entity), collectible_vote_buttons(entity, styling) ]
  end

  # Sort out a suitable URL to stuff into an image thumbnail for a recipe
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
    content_tag :div, link_to(content, decorator.url), options
  end

end
