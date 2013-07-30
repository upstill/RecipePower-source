module ExpressionsHelper
  
  def expression_link(expr)
    expr.tag ? tag_link(expr.tag) : "**no tag**"
  end
  
end
