module TagsHelper

  def tags_table
    stream_table [ "ID", "Name", "Type", "Usages", "Public?", "Similar", "Synonym(s)", "Meaning(s)", "", "" ]
  end

  # Emit a link to a tag using the tag's name and, optionally, its type and id
  def tag_link tag, with_id=false
    link_to_modal( tag.name, tag )+(with_id ? "(#{tag.typename} #{tag.id.to_s})" : "")
  end
  
  def summarize_tag withtype = false, do_link = true, with_id=false
    @tagserv ||= TagServices.new(@tag)
    ((withtype ? "<i>#{@tagserv.typename}</i> " : "" )+
      "'<strong>#{do_link ? tag_link(@tagserv.tag, with_id) : @tagserv.name}</strong>'").html_safe
  end
  
  def summarize_meaning
    @tagserv ||= TagServices.new(@tag)
    if (meaning = @tagserv.primary_meaning) && !meaning.description.blank?
      "<p class=\"airy\"><strong>...described as</strong> '#{@tagserv.primary_meaning.description}'</p>".html_safe
    end
  end
  
  def summarize_tag_owners
    @tagserv ||= TagServices.new(@tag)
    return if @tagserv.isGlobal || (owners = @tagserv.owners).empty?
    ownerstrs = owners.collect { |owner| owner.handle }
    tag_info_section ownerstrs, label: "...private to "
  end
  
  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def summarize_tag_similars args={} 
    @tagserv ||= TagServices.new(@tag)
    others = Tag.where(normalized_name: @tagserv.normalized_name).delete_if { |other| other.id == @tagserv.id } #  @tagserv.lexical_similars
    label= args[:label] || "Similar tags: "
    joiner = args[:joiner] || " " #  ", "
    ("<span>#{label}"+
        others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && @tagserv.can_absorb(other)) }.join(joiner)+
    "</span>").html_safe
    # tag_info_section others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && @tagserv.can_absorb(other)) }, label: label, joinstr: joiner
  end
  
  def summarize_tag_parents label = "Categorized Under: "
    @tagserv ||= TagServices.new(@tag)
    tag_info_section @tagserv.parents.collect { |parent_list| parent_list.collect { |parent| tag_link parent }.join('/&#8201')}, label: label
  end
	
  def summarize_tag_children label = "Examples: "
    @tagserv ||= TagServices.new(@tag)
    tag_info_section @tagserv.children.collect { |child| tag_link child }, label: label
  end
  
  def summarize_tag_referents
    @tagserv ||= TagServices.new(@tag)
    tag_info_section(
      @tagserv.referents.keep_if { |ref| ref != @tagserv.primary_meaning }.each { |ref|
      	summarize_referent ref, "Other Meaning(s)"
      }, label: "Referents: ")
  end
  
  def summarize_tag_recipes header="<h4>Used as Tag on Recipe(s)</h4>"
    @tagserv ||= TagServices.new(@tag)
    recipes =
      @tagserv.recipes(true).uniq.collect { |rcp| 
        content_tag :li, "#{link_to rcp.title, rcp.url} #{recipe_info_icon rcp}".html_safe, class: "tog_info_rcp_title"
      }
    unless recipes.empty?
      ("#{header}<ul>"+recipes.join('<br>')+"</ul>").html_safe
    end
  end

  # Return HTML for the links associated with this tag
  def summarize_tag_references label = "See "
    @tagserv ||= TagServices.new(@tag)
    refstrs = @tagserv.references.collect{ |reference| present_reference(reference) }
    unless refstrs.empty?
      (content_tag( :h3, "References")+
       content_tag( :div,
                  tag_info_section( refstrs, label: (label + "'#{@tagserv.name}'" + " on ") ).html_safe,
                  class: "container")).html_safe
    end
  end

  # Return HTML for the links related to a given tag (i.e., the links for 
  # all tags related to this one)
  def summarize_tag_relations label = "See Also"
    @tagserv ||= TagServices.new(@tag)
    content_tag( :h3, label)+
      Referent.related(@tagserv, false, true).collect { |rel|
        if(rel.id != @tagserv.id)  
          ts = TagServices.new(rel)
          refs = ts.references
          refstrs = refs.collect{ |reference| present_reference(reference) }
          content_tag(:div,
                      tag_info_section(refstrs, label: ("'#{rel.synonyms.map(&:name).join('/&#8201')}'" + " on ")).html_safe,
                      class: "container").html_safe unless refstrs.empty?
        end
      }.compact.join(', ').html_safe
  end

  def summarize_tag_synonyms label="Synonyms: "
    @tagserv ||= TagServices.new(@tag)
    # The synonyms are the other expressions of this tag's referents
    return if (syns = @tagserv.synonyms).empty?
    synstrs = syns.collect { |tag| tag_link tag }
    tag_info_section synstrs, label: label, joinstr: "<br>"
  end

  def summarize_tag_reference_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.reference_count) > 0) ? (pluralize(ct, "Reference").sub(/\s/, "&nbsp;")+"<br>").html_safe : ""
  end

  def summarize_tag_parents_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.parents.count) > 0) ? (pluralize(ct, "Parent").sub(/\s/, "&nbsp;")+"<br>").html_safe : ""
  end

  def summarize_tag_children_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.children.count) > 0) ? (pluralize(ct, "Child").sub(/\s/, "&nbsp;")+"<br>").html_safe : ""
  end
  
  def summarize_tag_recipe_count
    @tagserv ||= TagServices.new(@tag)
    count = @tagserv.recipe_ids(true).size
    return "" if count == 0
    (pluralize(count, "Recipe").sub(/\s/, " ")+"<br>").html_safe
  end
      
  def summarize_tag_owner_count
    @tagserv ||= TagServices.new(@tag)
      ct = @tagserv.user_ids.size
      (ct > 0) ? (pluralize(ct, "Owner").sub(/\s/, "&nbsp;")+"<br>").html_safe : ""
  end

=begin
  def summarize_tags(tags)
  	tags.collect{|tag| summarize_tag tag }.join(', ')
  end
=end
    
# ----------------------------------
    
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
  def tag_info_section contentstrs, options
    contentclass = options[:contentclass] || "tag_info_section_content"
    label = options[:label] || ""
    joinstr = options[:joinstr] || ", "
    if contentstrs && !contentstrs.empty?
      contentstr = contentclass.blank? ?
                   contentstrs.join('').html_safe :
                   content_tag(:span, contentstrs.join(joinstr).html_safe, class: contentclass)
      # content_tag( :div,
      #   (label+contentstr).html_safe,
      #  class: "tag_info_section"
      # )
      result =
      content_tag :div,
        content_tag( :div,
                     content_tag(:p, "<strong>#{label}</strong>".html_safe, class: "pull-right"),
                     class: "col-md-4")+
        content_tag( :div,
                     content_tag(:p, contentstr.html_safe, class: "pull-left"),
                     class: "col-md-8"),
        class: "row"
      result.html_safe
    end
  end
  
  def summarize_tag_similar tag, absorb_btn = false
      tagidstr = tag.id.to_s
      content_tag :span,
        tag_link(tag) +
        (absorb_btn ? link_to_submit("Absorb", "tags/#{tag.id.to_s}/absorb?victim=#{tagidstr}", class: "absorb_button", id: "absorb_button_#{tagidstr}") : ""),
        class: "absorb_"+tagidstr
  end

  # Present a collection of tags, by type
  def show_tags fields
    fields.collect { |field|
      if field.is_a? Array
        field, label = field[0], field[1]
      else
        label = field.sub "_tags", ''
        extension = label.pluralize.sub label, ''
        label << "(#{extension})" unless extension.blank?
      end
      render "tags/show_labelled", label: label, name: field
    }.join('').html_safe
  end

  def tag_filter_header locals={}
    locals[:type_selector] ||= false
    render "tags/tag_filter_header", locals # ttl: label, type_selector: type_selector
  end
end
