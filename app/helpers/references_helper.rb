module ReferencesHelper

  def reference_expressions(reference)
    reference.referents.collect { |rft| "<br>"+rft.expression.typename+": "+link_to(rft.expression.name, rft.expression) }.join.html_safe
  end
  
  # Show a reference, using as text the name of the related site
  def present_reference reference
    ref_link = (ref_name = reference.decorate.name).present? ?
        link_to(ref_name, reference.url, :target => '_blank') :
        "".html_safe
    if site = SiteReference.lookup_site(reference.url)
      ref_link << ' on '.html_safe unless ref_link.blank?
      ref_link << link_to(site.name, site.home, :target => '_blank')
    end
    ref_link
  end
end
