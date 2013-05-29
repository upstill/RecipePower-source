module TagsHelper
  
  def summarize_tag withtype = false, do_link = true
    @tagserv ||= TagServices.new(@tag)
    ((withtype ? "<i>#{@tagserv.typename}</i> " : "" )+
      "'<strong>#{do_link ? link_to(@tagserv.name, @tagserv.tag) : @tagserv.name}</strong>'").html_safe
  end
  
  def summarize_meaning
    @tagserv ||= TagServices.new(@tag)
    if (meaning = @tagserv.primary_meaning) && !meaning.description.blank?
      "<p class=\"airy\"><strong>...described as</strong> '#{@tagserv.primary_meaning.description}'</p>".html_safe
    end
  end
  
  def summarize_tag_owners
    @tagserv ||= TagServices.new(@tag)
    ownerstrs = @tagserv.isGlobal ? ["everyone (it's global)"] : @tagserv.owners.collect { |owner| owner.handle }
    tag_info_section "...owned by", ownerstrs
  end
  
  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def summarize_tag_similars args={} 
    @tagserv ||= TagServices.new(@tag)
    label= args[:label] || "Similar tags: "
    joiner = args[:joiner] || "" #  ", "
    others = Tag.where(normalized_name: @tagserv.normalized_name).delete_if { |other| other.id == @tagserv.id }
    tag_info_section label, others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && @tagserv.can_absorb(other)) }
  end
  
  def summarize_tag_parents label = "Categorized Under"
    @tagserv ||= TagServices.new(@tag)
    tag_info_section(label,     
      @tagserv.referents.collect { |ref| ref.parents }.flatten.uniq.collect { |parent| link_to parent.name, parent.canonical_expression }
    )
  end
	
  def summarize_tag_children label = "Examples"
    @tagserv ||= TagServices.new(@tag)
    tag_info_section(label,     
      @tagserv.referents.collect { |ref| ref.children }.flatten.uniq.collect { |child| link_to child.name, child.canonical_expression }
    )
  end
  
  def summarize_tag_referents
    @tagserv ||= TagServices.new(@tag)
    @tagserv.referents.keep_if { |ref| ref != @tagserv.primary_meaning }.each do |ref|
    	summarize_referent ref, "Other Meaning(s)"
    end
  end
  
  def summarize_tag_recipes
    @tagserv ||= TagServices.new(@tag)
    rcpstrs = @tagserv.recipes.uniq.collect { |rcp| 
      taglink = (permitted_to? :edit, rcp) ?
        link_to("[Tagger]", edit_recipe_path(rcp)) :
        ""
        %Q{<div class="tog_info_rcp_title">
        	   #{link_to rcp.trimmed_title, rcp.url} #{recipe_popup rcp} #{taglink}
           </div>}
      }
    tag_info_section "Recipes", rcpstrs, ""
  end

  # Return HTML for the links associated with this tag
  def summarize_tag_references label = "See "
    @tagserv ||= TagServices.new(@tag)
    tag_info_section(
      (label + "'#{@tagserv.name}'" + " on"), 
      @tagserv.references.collect{ |reference| content_tag :div, present_reference(reference), class: "tog_info_rcp_title" } 
    )
  end

  # Return HTML for the links related to a given tag (i.e., the links for 
  # all tags related to this one)
  def summarize_tag_relations label = "See Also "
    @tagserv ||= TagServices.new(@tag)
    tag_info_section( "See Also",
      Referent.related(@tagserv.tag, true, true).collect { |rel| 
        if(rel.id != @tagserv.id) &&  
          (tl = tag_info_section(
            (label + "'#{rel.name}'" + " on"), 
            TagServices.new(rel).references.collect{ |reference| content_tag :div, present_reference(reference), class: "tog_info_rcp_title" },
          ""))
          content_tag( :div, tl, class: "tog_info_rcp_title" ) 
        end
      }.compact,
    "")
  end

  def summarize_tag_reference_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.reference_count) > 0) ? pluralize(ct, "Reference").sub(/\s/, "&nbsp;").html_safe : ""
  end
  
  def summarize_tag_recipe_count
    @tagserv ||= TagServices.new(@tag)
    count = @tagserv.recipe_ids.size
    return "" if count == 0
    txt = pluralize(count, "Recipe").sub(/\s/, " ")
  end
      
  def summarize_tag_owner_count
    @tagserv ||= TagServices.new(@tag)
      ct = @tagserv.user_ids.size
      (ct > 0) ? pluralize(ct, "Owner").sub(/\s/, "&nbsp;").html_safe : ""
  end

  def summarize_tag_synonyms
    @tagserv ||= TagServices.new(@tag)
    # The synonyms are the other expressions of this tag's referents
    @tagserv.synonyms.collect { |tag| tag.name+"(#{tag.id.to_s})" }.join(', ').html_safe
  end

=begin
  def summarize_tags(tags)
  	tags.collect{|tag| summarize_tag tag }.join(', ')
  end
=end
    
  # ----------------------------------
  def taglink(id)
      if id
          tag = Tag.find id
          link_to(tag.name, tag)
      else
          "**no tag**"
      end
  end
    
    # Return HTML for each tag of the given type
    def taglist(taglist)
        taglist.map { |tag| grabtag tag }.join('').html_safe
    end
    
    def grabtag(tag)
        # orphantagid() is a helper method in application_controller.rb (so tags_controller can use it)
        ("<div class=\"orphantag\" id=\"#{orphantagid(tag.id)}\">#{tag.name}</div>").html_safe
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
                     content_tag(:span, contentstrs.join(', ').html_safe, class: contentclass)
        content_tag( :div, 
          content_tag( :span, label, class: "tag_info_section_title")+contentstr.html_safe, 
          class: "tag_info_section"
        )
        
    end
  end
  
  def summarize_tag_similar tag, absorb_btn = false
      tagidstr = tag.id.to_s
      "<span class=\"absorb_#{tagidstr}\">"+
      link_to( tag.name, tag)+
      "(#{tag.typename} #{tagidstr})"+
      (absorb_btn ? button_to_function("Absorb", "merge_tags();", class: "absorb_button", id: "absorb_tag_#{tagidstr}") : "")+
      "</span>" 
  end
end
