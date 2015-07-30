module PageletsHelper
  def pagelet_body_replacement entity_or_decorator=nil
    body_id = "pagelet-body"
    content =
    case entity_or_decorator
      when String
        # A string specifies a partial
        with_format("html") { render entity_or_decorator }
      when nil
        render_template response_service.controller, response_service.action
      else
        controller = (entity_or_decorator.is_a?(Draper::Decorator) ? entity_or_decorator.object : entity_or_decorator).class.to_s.underscore.pluralize
        body_id = pagelet_body_id entity_or_decorator
        with_format("html") { render_template(controller, :show) }
    end
    [ 'div.pagelet-body',
      content_tag(:div,
                  "#{pagelet_signin_links}#{content}".html_safe,
                  class: pagelet_class,
                  id: body_id) ]
  end

  def pagelet_filter_replacement querytags=[]
    [ 'div.global-search', pagelet_filter_header(querytags) ]
  end

  def pagelet_filter_header querytags=[]
    content_tag :div,
                with_format('html') { render 'layouts/filter_header', querytags: querytags },
                class: 'global-search '+(user_signed_in? ? 'container menuback' : 'searchtop')
  end

  # The class of the pagelet body, which depends on
  def pagelet_class
    if response_service.controller == "pages" && response_service.action == "home"
      "pagelet-body"
    else
      "pagelet-body container #{user_signed_in? ? 'top' : 'med'}"
    end
  end

  # Hang an id on the pagelet body for future conditional replacement
  def pagelet_body_id entity=nil
    entity ||= @decorator
    entity ? dom_id(entity) : "pagelet-body"
  end

  def pagelet_body_selector entity=nil
    "div.pagelet-body##{pagelet_body_id(entity)}"
  end

  def pagelet_signin_links
    unless user_signed_in?
      content_tag :div,
                  link_to_submit("Sign Up", new_user_registration_path, preload: true, mode: :modal)+
                  tag(:br)+
                  link_to_submit("Sign In", new_user_session_path, preload: true, mode: :modal),
                  class: 'signin-link'
    end
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
