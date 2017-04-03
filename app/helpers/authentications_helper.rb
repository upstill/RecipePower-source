module AuthenticationsHelper

  # Offer an authentication option in the form of an icon and a title
  def auth_possible(service, origin, originator, intention, options = {})
    service = service.downcase
    svc_lower = options[:svc_lower] || service
    return if @authentications && @authentications.any? { |authentication| authentication.provider.match(/^#{svc_lower}/) }

    query_params = {intention: intention, originator: %Q{"#{originator}"}}
    if origin
      query_params[:origin] = '"' + URI::encode(response_service.decorate_path(origin)) + '"'
    end
    auth_url = assert_query "#{rp_url '/auth/'+svc_lower}", query_params

    link = content_tag :a,
                       image_tag(service+'.svg', :alt => service, class: service), # +service,
                       :class => 'auth_provider small',
                       :size => "32x32",
                       :href => auth_url,
                       :onclick => "RP.authentication.connect(event)", # response_service.injector? ? "yield_iframe(event)" : "RP.authentication.connect(event)",
                       :"data-hold_msg" => "Hang on while we check with "+service+"...",
                       :"data-width" => 600,
                       :"data-height" => 300
    content_tag :div, link.html_safe, class: " auth #{svc_lower}", style: "display: inline-block;"
  end

end
