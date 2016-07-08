module ReferencesHelper

  def reference_expressions(reference)
    reference.referents.collect { |rft| "<br>"+rft.expression.typename+": "+link_to(rft.expression.name, rft.expression) }.join.html_safe
  end
  
  # Show a reference, using as text the name of the related site
  def present_reference reference, ref_name=''
      (site = Site.find_or_create reference.url) ? link_to("#{(ref_name + ' on ') if ref_name.present?}#{site.name}", reference.url) : ""
  end
end
