module ExpressionsHelper
  
  def expression_link(expr)
    expr.tag ? homelink(expr.tag) : "**no tag**"
  end

  def expression_name expr
    expr.tag ? expr.tag.name : '**no tag**'
  end
  
end
