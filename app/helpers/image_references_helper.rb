module ImageReferencesHelper

  def image_reference_expressions(reference)
    reference.referents.collect { |rft| "<br>"+rft.expression.typename+": "+link_to(rft.expression.name, rft.expression) }.join.html_safe
  end
  
end
