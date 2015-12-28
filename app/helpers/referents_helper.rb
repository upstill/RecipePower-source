module ReferentsHelper

  def referent_homelink ref, options={}
    action = options.extract!(:action)[:action] || :associated
    pathspec = action ? polymorphic_path([action, ref.becomes(Referent)]) : ref.becomes(Referent)
    link_to_submit ref.name, pathspec, { :mode => :partial }.merge(options)
  end

  def list_expressions referent, do_tag=true
    ("Expressions: "+(referent.expressions.collect { |expr| 
      "<br>&nbsp;&nbsp;'"+
      begin
        tag = Tag.find(expr.tag_id)
        locale = expr.locale || "(nil)"
        form = expr.form || "(nil)"
        (do_tag ? tag_homelink(tag) : tag.name)+
        "'(id #{tag.id.to_s}, form #{form}, locale #{locale})"
      rescue
        "<Missing tag##{expr.tag_id}>"
      end
    }.join(', ') || "none")).html_safe
  end
    
	def list_parents referent, do_tag=true
    ("Parents: "+(referent.parent_tags.collect { |tag| 
        (do_tag ? tag_homelink(tag) : tag.name)+
        "(id #{tag.id.to_s})"
      }.join(', ') || "none")).html_safe
  end
    
	def list_children referent, do_tag=true
    ("Children: "+
      (referent.child_tags.collect { |tag| 
        (do_tag ? tag_homelink(tag) : tag.name)+
        "(id #{tag.id.to_s})"
      }.join(', ') || "none")).html_safe
  end

	def summarize_ref_name referent, long=false
    extra = long ? "going by the name of " : ""
    "<i>#{referent.typename}</i> #{extra}<strong>'#{referent.name}'</strong> ".html_safe
	end
	
	def summarize_referent ref, label="...Meaning"
    ("<br>#{label}: ''#{referent_homelink ref}':"+
    summarize_ref_parents(ref)+
    summarize_ref_children(ref)).html_safe
  end
    
	def summarize_ref_parents ref, label = "...Categorized under"
    if ref.parents.size > 0
      ("<br>#{label}: "+
      (ref.parents.collect { |parent| referent_homelink parent.becomes(Referent) }.join ', ')).html_safe
    else
      ''
    end
	end
	
	def summarize_ref_children ref, label = "...Examples"
    if ref.children.size > 0
      ("<br>#{label}: "+
      (ref.children.collect { |child| referent.homelink child.becomes(Referent) }.join ', ')).html_safe
    else
      ''
    end
	end
end
