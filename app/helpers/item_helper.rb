module ItemHelper

  # Prep for rendering an item in a particular mode: sort out the parameters and initialize @decorator
  def item_preflight item_or_decorator_or_specs=nil, item_mode=nil
    if item_or_decorator_or_specs.is_a? Symbol
      item_or_decorator_or_specs, item_mode = nil, item_or_decorator_or_specs
    end
    item_mode ||= response_service.item_mode
    if item = (item_or_decorator_or_specs.is_a?(Draper::Decorator) ? item_or_decorator_or_specs.object : item_or_decorator_or_specs) || (@decorator.object if @decorator)
      unless @decorator && @decorator.object == item
        controller.update_and_decorate item
        @decorator = controller.instance_variable_get :"@decorator"
        instance_variable_set :"@#{item.class.to_s.underscore}", item
      end
    end
    [ item, item_mode ]
  end

  def item_partial_class item_mode, decorator=@decorator
    itemclass = "#{item_mode}-item" if item_mode
    domid = "#{decorator.dom_id}" if decorator
    "#{itemclass} #{domid}"
  end

  def item_partial_selector item_or_decorator_or_specs=nil, item_mode=nil, context=nil
    item, item_mode = item_preflight item_or_decorator_or_specs, item_mode
    tag = case item_mode
            when :table
              'tr'
            when :homelink
              'span'
            else
              'div'
          end
    "#{tag}." + item_partial_class(item_mode).gsub(' ', '.')
  end

  # container_selector and wrapper_selector are adopted from masonry_helper.rb and are currently only for masonry lists
  # TODO: generalize these for all items
  def item_container_selector entity_or_string=nil, context=nil
    entity_or_string ||= current_user_or_guest
    masonry_id = entity_or_string.is_a?(String) ? entity_or_string : "#{dom_id entity_or_string}_contents"
    masonry_id = "div#"+masonry_id unless masonry_id.blank?  # Prepend the id selector
    "#{masonry_id} div.js-masonry"
  end

  # Provide a selector that finds the wrapper for a specific masonry item (given by entity_or_string)
  def item_wrapper_selector decorator, context=nil
    "#{item_container_selector decorator, context} div.masonry-item.#{decorator.dom_id}"
  end

  # The item partial depends on the item mode (:table, :modal, :masonry, :slider),
  # defaulting to just "_show"
  def item_partial_name item_or_decorator_or_specs=nil, item_mode=nil
    item, item_mode = item_preflight item_or_decorator_or_specs, item_mode
    if item_mode == :comments
      "show_comments" if [Recipe, List].include?(item.class)
    else
      tail = item_or_decorator_or_specs ? "show" : "index"
      tail << "_#{item_mode}" if item_mode
      if item
        item_class = item.class.to_s.pluralize
        ctrl_class = (item_class+"Controller").constantize rescue nil
        view = ctrl_class ? response_service.find_view(ctrl_class, '_'+tail) : "#{item_class.underscore}/_#{tail}"
        view.sub('/_', '/')
      else
        tail
      end
    end
  end

  # Define a :replacements item to replace a particular item under an item mode (defaulting to the item_mode parameter)
  def item_replacement item_or_decorator_or_specs=nil, item_mode=nil, locals={}
    item, item_mode = item_preflight item_or_decorator_or_specs, item_mode
    # Ensure viewparams
    viewparams = FilteredPresenter.new(self, response_service, { item_mode: item_mode }, @decorator).viewparams
    [ item_partial_selector(item, item_mode), render_item(item, item_mode, viewparams: viewparams) ]
  end

  # Generate replacements for all versions of the item
  def item_replacements item_or_decorator_or_specs, types=[:table, :masonry, :slider, :card, :homelink]
    types.collect { |item_mode|
      item_replacement item_or_decorator_or_specs, item_mode
    }.compact
  end

  # Define a :replacements item to delete the item node for @decorator
  def item_deleter item_or_decorator_or_specs=nil, item_mode=nil, context=nil
    item, item_mode = item_preflight item_or_decorator_or_specs, item_mode
    [ item_partial_selector(item, item_mode, context) ]
  end

  # Generate deleters for all versions of an item, and, if we're on its page, a pagelet replacement returning to the user's home page
  def item_deleters item_or_decorator_or_specs, context=nil
    [:table, :modal, :masonry, :slider, :homelink].collect { |item_mode|
      item_deleter item_or_decorator_or_specs, item_mode, context
    }.compact << pagelet_body_replacement(item_or_decorator_or_specs, true)
  end

  def item_insertion decorator, context=nil
    [ item_wrapper_selector(decorator, context),
      render_item(decorator, :masonry),
      item_container_selector(decorator, context) ]
  end

  # TODO: should apply to other aggregates, not just :masonry (i.e., :table and :slider)
  def item_insertions decorator, context=nil
    [ item_insertion(decorator, context) ]
  end

  def render_item_unwrapped item_or_decorator_or_specs=nil, item_mode=nil, locals={}
    if item_mode.is_a? Hash
      item_mode, locals = nil, item_mode
    end
    item, item_mode = item_preflight item_or_decorator_or_specs, (item_mode || :card)
    if partial = item_partial_name(item, item_mode)
      with_format("html") { render partial, locals.merge(decorator: @decorator) }
    end
  end

  def render_item item_or_decorator_or_specs=nil, item_mode=nil, locals={}
    if item_mode.is_a? Hash
      item_mode, locals = nil, item_mode
    end
    # item_or_decorator_or_specs is defined recursively: if it's an array, we recur on each member of the array, joining the
    # results
    if item_or_decorator_or_specs.is_a? Array
      rendering = item_or_decorator_or_specs.collect { |spec| 
        render_item *spec 
      }.join('').html_safe
    else
      rendering = render_item_unwrapped item_or_decorator_or_specs, item_mode, locals # locals are the local bindings for the item
      return "" unless rendering.present?
      item, item_mode = item_preflight item_or_decorator_or_specs, item_mode
    end
    container_class = item_partial_class item_mode
    # Encapsulate the rendering in the standard shell for the item mode
    case item_mode
      when :querify
        querify_block locals.delete(:url), rendering, locals # Locals are the options for querify_block
      when :partial
        # Enclose the rendering in a partial named by locals[:partial_name] or implied by :partial and the controller action
        if partial_name = locals.delete(:partial_name) || item_partial_name(item, item_mode)
          with_format("html") { render partial_name, locals.merge(content: rendering) }
        end
      when :masonry
        content_tag :div, rendering, class: container_class+" stream-item"
      when :modal
        modal_dialog :"#{response_service.action}_#{response_service.controller.singularize}",
                     response_service.title,
                     :body_contents => rendering.html_safe
      when :slider
        content_tag :div, rendering, class: container_class
      when :table
        content_tag(:tr,
                    rendering,
                    class: container_class).html_safe
    end || rendering
  end

  # Syntactic sugar to package up the parameters to render_item for recursive description
  def item_to_render *args
    args
  end

end
