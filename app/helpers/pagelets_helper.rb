module PageletsHelper
  def pagelet_body_replacement entity_or_decorator=nil
    pbclass = "pagelet-body"
    div_options = { class: pbclass }
    content =
    case entity_or_decorator
      when String
        # A string specifies a partial
        with_format("html") { render entity_or_decorator }
      when nil
        render_template(response_service.controller, response_service.action)
      else
        controller = (entity_or_decorator.is_a?(Draper::Decorator) ? entity_or_decorator.object : entity_or_decorator).class.to_s.underscore.pluralize
        div_options[:id] = pagelet_body_id entity_or_decorator
        with_format("html") { render_template(controller, :show) }
    end
    [ "div.#{pbclass}", content_tag(:div, content, div_options) ]
  end

  # Hang an id on the pagelet body for future conditional replacement
  def pagelet_body_id entity=nil
    entity ||= @decorator
    entity ? dom_id(entity) : "pagelet-body"
  end

  def pagelet_body_selector entity=nil
    "div.pagelet-body##{pagelet_body_id(entity)}"
  end

  # Return the followup after updating or destroying an entity: replace its pagelet with either an update, or the list of such entities
  def pagelet_followup entity, destroyed=false
    entity = entity.object if entity.is_a? Draper::Decorator
    request =
        destroyed ?
            user_collection_path(current_user) :
            polymorphic_path(entity, :nocache => true)
    {
        request: request,
        target: pagelet_body_selector(entity)
    }
  end
end
