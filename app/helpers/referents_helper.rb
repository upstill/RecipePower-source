module ReferentsHelper
    
    def list_expressions referent, do_tag=true
        ("Expressions: "+(referent.expressions.collect { |expr| 
            tag = Tag.find(expr.tag_id)
            locale = expr.locale || "(nil)"
            form = expr.form || "(nil)"
            "<br>&nbsp;&nbsp;'"+
            (do_tag ? link_to(tag.name, tag) : tag.name)+
            "'(id #{tag.id.to_s}, form #{form}, locale #{locale})"
        }.join(', ') || "none")).html_safe
    end
    
	def list_parents referent, do_tag=true
	    ("Parents: "+(referent.parent_tags.collect { |tag| 
            (do_tag ? link_to(tag.name, tag) : tag.name)+
            "(id #{tag.id.to_s})"
        }.join(', ') || "none")).html_safe
    end
    
	def list_children referent, do_tag=true
	    ("Children: "+
	    (referent.child_tags.collect { |tag| 
            (do_tag ? link_to(tag.name, tag) : tag.name)+
            "(id #{tag.id.to_s})"
        }.join(', ') || "none")).html_safe
    end
	
	def summarize_ref_name referent, long=false
	    ("#{referent.id.to_s}: "+
	    "<i>#{referent.typename}</i> "+
	    "<strong>\"#{referent.name}\"</strong> "+
	    (long ? "" : "")
	    ).html_safe
	end
	
	def summarize_referent ref, label="...Meaning"
      ("<br>#{label}: ''#{link_to ref.name, referent_path(ref)}':"+
       summarize_ref_parents(ref)+
       summarize_ref_children(ref)).html_safe
    end
    
	def summarize_ref_parents ref, label = "...Categorized under"
        if ref.parents.size > 0
    		("<br>#{label}: "+
	        (ref.parents.collect { |parent| link_to parent.name, parent.becomes(Referent) }.join ', ')).html_safe
	    else
	        ""
        end
	end
	
	def summarize_ref_children ref, label = "...Examples"
        if ref.children.size > 0
    		("<br>#{label}: "+
	        (ref.children.collect { |child| link_to child.name, child.becomes(Referent) }.join ', ')).html_safe
	    else
	        ""
        end
	end
end
