module ExpressionsHelper
  
  def expression_link(expr)
    expr.tag ? tag_homelink(expr.tag) : "**no tag**"
  end
  
end
