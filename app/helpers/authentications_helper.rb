module AuthenticationsHelper
  
  # Offer an authentication option in the form of an icon and a title
  def auth_possible(service, svc_lower=nil, small=false)
    svc_lower ||= service.downcase
    auth_url = "http://#{current_domain}/auth/"+svc_lower
    css_class = "auth_provider"
    css_class += " small" if small
    css_class += " hide" if @authentications && @authentications.any? { |authentication| authentication.provider.match(/^#{svc_lower}/) }
    content_tag :a, image_tag( (svc_lower+"_64.png"), :size => "64x64", :alt => service)+service, href: auth_url, class: css_class
    # link_to_submit image_tag( (svc_lower+"_64.png"), :size => "64x64", :alt => service)+service, auth_url, class: css_class
  end

end
