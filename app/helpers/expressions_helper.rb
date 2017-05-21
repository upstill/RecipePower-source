module ExpressionsHelper
  
  def expression_link(expr)
    expr.tag ? homelink(expr.tag) : "**no tag**"
  end
  
end
