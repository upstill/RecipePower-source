module PageRefsHelper

  def page_ref_homelink pr
    link_to (pr.title.present? ? pr.title : pr.url), pr.url
  end

  # Show a reference, using as text the name of the related site
  def present_definition def_page_ref
    ref_link = (ref_name = def_page_ref.decorate.name).present? ?
        link_to(ref_name, def_page_ref.url, :target => '_blank') :
        "".html_safe
    if site = def_page_ref.site
      ref_link << ' on '.html_safe unless ref_link.blank?
      ref_link << link_to(site.name, site.home, :target => '_blank')
    end
    ref_link
  end
end
