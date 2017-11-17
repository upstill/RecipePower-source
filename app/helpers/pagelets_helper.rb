module PageletsHelper

  def pagelet_body_replacement entity_or_decorator=nil, to_delete=false
    body_id = 'pagelet-body'
    selector = 'div.pagelet-body'
    content =
    case entity_or_decorator
      when String
        # A string specifies a partial
        with_format('html') { render entity_or_decorator }
      when nil
        render_template response_service.controller, response_service.action
      else
        if to_delete
          selector << '.' + (entity_or_decorator.is_a?(Draper::Decorator) ? entity_or_decorator : entity_or_decorator.decorate).dom_id
          link_to_submit '', current_user, trigger: true
        else
          controller = (entity_or_decorator.is_a?(Draper::Decorator) ? entity_or_decorator.object : entity_or_decorator).class.to_s.underscore.pluralize
          body_id = pagelet_body_id entity_or_decorator
          with_format('html') { render_template(controller, :show) }
        end
    end
    # Add script code to update the notifications
    content += check_for_notifications if current_user
    [ selector,
      content_tag(:div,
                  (flash_notifications_div+content).html_safe,
                  class: pagelet_class,
                  id: body_id) ]
  end

  # The class of the pagelet body, which depends on
  def pagelet_class
    if response_service.controller == 'pages' && response_service.action == 'home'
      'pagelet-body'
    else
      "pagelet-body container #{@decorator.dom_id if @decorator}"
    end
  end

  # Hang an id on the pagelet body for future conditional replacement
  def pagelet_body_id entity=nil
    entity ||= @decorator
    entity ? dom_id(entity) : 'pagelet-body'
  end

  def pagelet_body_selector entity=nil
    "div.pagelet-body.#{pagelet_body_id(entity)}"
  end

  # Return the followup after updating or destroying an entity: replace its pagelet with either an update, or the list of such entities
  def pagelet_followup decorator, destroyed=false
    entity = decorator.object 
    request =
        destroyed ?
            collection_user_path(current_user) :
            polymorphic_path(decorator, :nocache => true)
    {
        request: request,
        target: pagelet_body_selector(entity)
    }
  end
end
