module TagsHelper
    
    def taglink(id)
        if id
            tag = Tag.find id
            link_to(tag.name, tag)
        else
            "**no tag**"
        end
    end
    
    def count_recipes tag
        count = tag.recipe_ids.size
        return "" if count == 0
        txt = pluralize(count, "Recipe").sub(/\s/, " ")
        link_to(txt, new_rcpquery_path(tag: tag.id.to_s))
    end
        
    def count_owners tag
        ct = tag.user_ids.size
        (ct > 0) ? pluralize(ct, "Owner").sub(/\s/, "&nbsp;").html_safe : ""
    end
        
    def count_links tag
        ct = tag.link_ids.size
        (ct > 0) ? pluralize(ct, "Link").sub(/\s/, "&nbsp;").html_safe : ""
    end
        
    def summarize_synonyms tag
        # The synonyms are the other expressions of this tag's referents
        ids = tag.referents.collect { |ref| ref.tag_ids }.flatten.uniq.delete_if { |id| id == tag.id }
        ids.empty? ? "" : ids.collect { |id| Tag.find(id).name+"(#{id.to_s})" }.join(', ').html_safe
    end
    
    def summarize_tag tag, withtype = false
	    ((withtype ? "<i>#{tag.typename}</i> " : "" )+
        "'<strong>#{link_to(tag.name, tag)}</strong>'").html_safe
    end
    
    def summarize_tags(tags)
    	tags.collect{|tag| summarize_tag tag }.join(', ')
    end
    
    # Return HTML for each tag of the given type
    def taglist(taglist)
        taglist.map { |tag| grabtag tag }.join('').html_safe
    end
    
    def grabtag(tag)
        # orphantagid() is a helper method in application_controller.rb (so tags_controller can use it)
        if link = tag.links.first
            name = "<a href=\"#{link.uri}\">#{tag.name}</a>"
        else
            name = tag.name
        end
        ("<div class=\"orphantag\" id=\"#{orphantagid(tag.id)}\">"+name+"</div>").html_safe
    end
    
    # Build a set of tabs for use by jQuery UI, with the current tab given as a parameter
    def tags_tabset(tabindex)
   	    tabstrs = ""
   	    ix = 0
   	    type = 0 # Index 0 yields type nil
   	    while type
   	        label = Tag.typename(type).to_s.pluralize
   	        tabstrs += <<BLOCK_END
       		    <li class="tag_tab"><a href="tags/list?tabindex=#{ix.to_s}" title="#{label}">#{label}</a></li> 
BLOCK_END
   	        type = Tag.index_to_type(ix+=1) # we get nil when we've run off the end of the table
        end
        s = <<BLOCK_END
<div id="tags_tabset" value=#{tabindex.to_s} > 
  <ul>
    #{tabstrs}
  </ul> 
</div>
BLOCK_END
         s.html_safe
       end
       
   # Helper to define a selection menu for tag type
   def type_selections val=nil
       if val.kind_of? Tag
           options_for_select(Tag.type_selections, val.typenum )
       elsif val.nil?
           options_for_select(Tag.type_selections )
       else
           options_for_select(Tag.type_selections, val )
       end
   end
  
  # Present one section of the tag info using a label, a (possibly empty) collection
  # of descriptive strings, and a classname for a span summarizing the section (presumably
  # because the individual entries are meant to show on a line). 
  # If the collection is empty, we return nil; if the contentclass is blank we don't wrap it in a span
  def tag_info_section label, contentstrs, contentclass = "tag_info_section_content"
    if contentstrs && !contentstrs.empty?
        contentstr = contentclass.blank? ? 
                     contentstrs.join('') : 
                     ("<span class=\"#{contentclass}\">" + contentstrs.join(', ') + "</span>")
        ("<div class=\"tag_info_section\"><span class=\"tag_info_section_title\">#{label}</span>: " +
         contentstr +
         "</div>"
        ).html_safe
    end
  end
       
  # Return HTML for the links associated with this tag
   def summarize_tag_links tag, label = "See "
     tag_info_section(
       (label + "'#{tag.name}'" + " on"), 
       tag.links.collect{ |link| "<div class=\"tog_info_rcp_title\">" + present_link(link) + "</div>" },
       "")
   end
       
  # Return HTML for the links related to a given tag (i.e., the links for 
  # all tags related to this one)
  def summarize_tag_relations tag
    links = Referent.related(tag, true, true).keep_if{ |rel| rel.id != tag.id }.collect { |rel| 
            if tl = summarize_tag_links(rel, "") 
                "<div class=\"tog_info_rcp_title\">"+tl+"</div>"                
            end
        }.keep_if{ |s| !s.blank? }
    tag_info_section "See Also", links, ""
  end
  
  def summarize_tag_recipes tag
    rcpstrs = tag.recipes.uniq.collect { |rcp| 
        taglink = (permitted_to? :edit, rcp) ?
          link_to("[Tagger]", edit_recipe_path(rcp)) :
          ""
          %Q{<div class="tog_info_rcp_title">
          	   #{link_to rcp.trimmed_title, rcp.url} #{recipe_popup rcp} #{taglink}
             </div>}
        }
    tag_info_section "Recipes", rcpstrs, ""
  end
  
  def summarize_tag_parents tag, label = "Categorized Under"
    if ref = tag.primary_meaning
	  tag_info_section label, ref.parents.collect { |parent| link_to parent.name, parent.canonical_expression }
    end
  end
	
  def summarize_tag_children tag, label = "Examples"
    if ref = tag.primary_meaning
      tag_info_section label, ref.children.collect { |child| link_to child.name, child.canonical_expression }
    end
  end
  
  def summarize_tag_owners tag
      ownerstrs = tag.isGlobal ? ["everyone (it's global)"] : tag.users.collect { |user| user.username }
      tag_info_section "It's owned by", ownerstrs
  end
  
  def summarize_tag_similar tag, absorb_btn = false
      tagidstr = tag.id.to_s
      "<span class=\"absorb_#{tagidstr}\">"+
      link_to( tag.name, tag)+
      "(#{tag.typename} #{tagidstr})"+
      (absorb_btn ? button_to_function("Absorb", "merge_tags();", class: "absorb_button", id: "absorb_tag_#{tagidstr}") : "")+
      "</span>" 
  end
  
  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def summarize_tag_similars tag, args={} 
      label= args[:label] || "Similar tags"
      joiner = args[:joiner] || "" #  ", "
      others = Tag.where(normalized_name: tag.normalized_name).delete_if { |other| other.id == tag.id }
      # otherstrs = others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && tag.can_absorb(other)) }
      tag_info_section label, others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && tag.can_absorb(other)) }
  end
end
