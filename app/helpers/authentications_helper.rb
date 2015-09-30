module AuthenticationsHelper

  # Offer an authentication option in the form of an icon and a title
  def auth_possible(service, origin, originator, intention, options = {} )
    svc_lower = options[:svc_lower] || service.downcase
    return if @authentications && @authentications.any? { |authentication| authentication.provider.match(/^#{svc_lower}/) }

    query_params = { intention: intention, originator: %Q{"#{originator}"} }
    if origin
      query_params[:origin] = '"' + URI::encode( response_service.decorate_path( origin )) + '"'
    end
    auth_url = assert_query "#{rp_url '/auth/'+svc_lower}", query_params

    css_class = "auth_provider"
    css_class += " small" # if response_service.injector?
    # css_class += " hide" if @authentications && @authentications.any? { |authentication| authentication.provider.match(/^#{svc_lower}/) }
    link = content_tag :a, image_tag( (svc_lower+"_32.png"), :alt => service), # +service,
      :class => css_class,
      :size => "32x32",
      :href => auth_url, 
      :onclick => "RP.authentication.connect(event)", # response_service.injector? ? "yield_iframe(event)" : "RP.authentication.connect(event)",
      :"data-hold_msg" => "Hang on while we check with "+service+"...",
      :"data-width" => 600, 
      :"data-height" => 300
    content_tag :div, link.html_safe, class: " auth #{svc_lower}", style: "display: inline-block;"
  end

end
