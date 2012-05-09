module ReferentsHelper
    
    def list_expressions referent 
        "Expressions: "+(referent.expressions.collect { |expr| 
            tag = Tag.find(expr.tag_id)
            locale = expr.locale || "(nil)"
            form = expr.form || "(nil)"
            "'#{tag.name}'(id #{tag.id.to_s}, form #{form}, locale #{locale})"
        }.join(', ') || "none")
    end
    
	def list_parents referent 
	    "Parents: "+(referent.parents.collect { |parent| 
            tag = Tag.find(parent.tag_id)
            "'#{tag.name}'(id #{tag.id.to_s})"
        }.join(', ') || "none")
    end
    
	def list_children referent 
	    "Children: "+(referent.children.collect { |child| 
            tag = Tag.find(child.tag_id)
            "'#{tag.name}'(id #{tag.id.to_s})"
        }.join(', ') || "none")
    end
	
	def summarize_referent referent
	    ("#{referent.id.to_s}: "+
	    "<strong>\"#{referent.name}\"</strong> "+
	    "(<i>#{referent.referent_typename}</i>) "
	    ).html_safe
	end
	
end
