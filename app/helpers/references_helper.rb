module ReferencesHelper
  
  def reference_expressions(reference)
    reference.referents.collect { |rft| "<br>"+rft.expression.typename+": "+rft.expression.name }.join.html_safe
  end
end
