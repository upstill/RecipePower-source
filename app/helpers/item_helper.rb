module ItemHelper

  def item_partial_selector item=nil, item_mode=nil
    item, item_mode = item_preflight item, item_mode
    tagname = item_mode==:table ? "td" : "div"
    "#{tagname}.#{item_mode}-item.#{dom_id @decorator.object}"
  end

  # Prep for rendering an item in a particular mode: sort out the parameters and initialize @decorator
  def item_preflight item=nil, item_mode=nil
    if item.is_a? Symbol
      item, item_mode = nil, item
    end
    item ||= @decorator.object if @decorator
    item_mode ||= response_service.item_mode
    unless @decorator && @decorator.object == item
      controller.update_and_decorate item
      @decorator = controller.instance_variable_get :"@decorator"
      instance_variable_set :"@#{item.class.to_s.underscore}", item
    end
    [ item, item_mode ]
  end

  # The item partial depends on the item rendering mode (:table, :page, :modal, :masonry, :slider),
  # defaulting to just "_show"
  def item_partial_name item=nil, item_mode=nil
    item, item_mode = item_preflight item, item_mode
    tail = item_mode ? "_show_#{item_mode}" : "_show"
    ctrl_class = (item.class.to_s.pluralize+"Controller").constantize
    response_service.find_view(ctrl_class, tail).sub('/_', '/')
  end

  # Define a :replacements item to replace a particular item under an item mode (defaulting to the item_mode parameter)
  def item_replacement item=nil, item_mode=nil
    item, item_mode = item_preflight item, item_mode
    [ item_partial_selector(item, item_mode), render_item(item, item_mode) ]
  end

  # Define a :replacements item to delete the item node for @decorator
  def item_deleter item=nil, item_mode=nil
    item, item_mode = item_preflight item, item_mode
    [ item_partial_selector(item, item_mode) ]
  end

  def render_item_unwrapped item=nil, item_mode=nil
    item, item_mode = item_preflight item, item_mode
    with_format("html") { render item_partial_name(item, item_mode), presenter: @presenter }
  end

  def render_item item=nil, item_mode=nil
    item, item_mode = item_preflight item, item_mode
    rendering = render_item_unwrapped item, item_mode
    # Encapsulate the rendering in the standard shell for the item mode
    case item_mode
      when :page
        content_tag(:div,
                    content_tag(:div, rendering, class: "col-md-12"),
                    class: "page-item row #{@decorator.dom_id.to_s}").html_safe
      when :modal
        modal_dialog :"#{response_service.action}_#{response_service.controller.singularize}", response_service.title do
          rendering
        end
      when :slider
        content_tag :div, rendering, class: "slider-item #{dom_id @decorator.dom_id}"
      when :table
        content_tag(:tr,
                    rendering,
                    class: "table-item #{@decorator.dom_id.to_s}").html_safe
    end
  end

end