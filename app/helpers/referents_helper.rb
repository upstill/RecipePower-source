module ReferentsHelper
    
    def list_expressions referent, do_tag=true
        ("Expressions: <ul>"+(referent.expressions.collect { |expr| 
            tag = Tag.find(expr.tag_id)
            locale = expr.locale || "(nil)"
            form = expr.form || "(nil)"
            "<li>'"+
            (do_tag ? link_to(tag.name, tag) : tag.name)+
            "'(id #{tag.id.to_s}, form #{form}, locale #{locale})</li>"
        }.join(', ')+"</ul>" || "none")).html_safe
    end
    
	def list_parents referent, do_tag=true
	    "Parents: "+(referent.parents.collect { |parent| 
            tag = Tag.find(parent.tag_id)
            "'"+
            (do_tag ? link_to(tag, tag.name) : tag.name)+
            "'"+
            "(id #{tag.id.to_s})"
        }.join(', ') || "none").html_safe
    end
    
	def list_children referent, do_tag=true
	    "Children: "+(referent.children.collect { |child| 
            tag = Tag.find(child.tag_id)
            "'"+
            (do_tag ? link_to(tag, tag.name) : tag.name)+
            "'"+
            "(id #{tag.id.to_s})"
        }.join(', ') || "none").html_safe
    end
	
	def summarize_referent referent, long=false
	    ("#{referent.id.to_s}: "+
	    "<i>#{referent.referent_typename}</i> "+
	    "<strong>\"#{referent.name}\"</strong> "+
	    (long ? "" : "")
	    ).html_safe
	end
	
end
