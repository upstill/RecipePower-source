module TagsHelper

=begin
  def tag_homelink tag, options={}
    homelink tag, options
  end

  def present_tag_name withtype = false, do_link = true
    @tagserv ||= TagServices.new(@tag)
    ((withtype ? "<i>#{@tagserv.typename}</i> " : "" )+
      "'<strong>#{do_link ? homelink(@tagserv.tag) : @tagserv.name}</strong>'").html_safe
  end

  def present_tag_meaning
    @tagserv ||= TagServices.new(@tag)
    if (meaning = @tagserv.primary_meaning) && !meaning.description.blank?
      "<p class=\"airy\"><strong>...described as</strong> '#{@tagserv.primary_meaning.description}'</p>".html_safe
    end
  end

  def present_tag_owners
    @tagserv ||= TagServices.new(@tag)
    return if @tagserv.isGlobal || (owners = @tagserv.owners).empty?
    ownerstrs = owners.collect { |owner| owner.handle }
    tag_info_section ownerstrs, label: '...private to '
  end
  
  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def present_tag_similars args={}
    @tagserv ||= TagServices.new(@tag)
    others = Tag.where(normalized_name: @tagserv.normalized_name).to_a.delete_if { |other| other.id == @tagserv.id } #  @tagserv.lexical_similars
    label= args[:label] || 'Similar tags: '
    joiner = args[:joiner] || ' ' #  ', '
    ("<span>#{label}"+
        others.collect { |other| similar other, (args[:absorb_btn] && @tagserv.can_absorb(other)) }.join(joiner)+
    "</span>").html_safe
    # tag_info_section others.collect { |other| summarize_tag_similar other, (args[:absorb_btn] && @tagserv.can_absorb(other)) }, label: label, joinstr: joiner
  end

  def present_tag_parents label = "Categorized Under: "
    @tagserv ||= TagServices.new(@tag)
    tag_info_section @tagserv.parents.collect { |parent| homelink parent }, label: label
  end
	
  def present_tag_children label = "Examples: "
    @tagserv ||= TagServices.new(@tag)
    tag_info_section @tagserv.children.collect { |child| homelink child }, label: label
  end
  
  def present_tag_referents
    @tagserv ||= TagServices.new(@tag)
    tag_info_section(
      @tagserv.referents.to_a.keep_if { |ref| ref != @tagserv.primary_meaning }.each { |ref|
      	summarize_referent ref, label: "Other Meaning(s)"
      }, label: "Referents: ")
  end

  def present_tag_recipes header="<h4>Used as Tag on Recipe(s)</h4>"
    @tagserv ||= TagServices.new(@tag)
    recipes =
      @tagserv.recipes(true).uniq.collect { |rcp| 
        content_tag :li, "#{link_to rcp.title, rcp.url} #{collectible_info_icon rcp.decorate}".html_safe, class: "tog_info_rcp_title"
      }
    unless recipes.empty?
      ("#{header}<ul>"+recipes.join('<br>')+"</ul>").html_safe
    end
  end

  # Return HTML for the links associated with this tag
  def present_tag_references label = "See "
    @tagserv ||= TagServices.new(@tag)
    unless (refstrs = present_tag_definitions @tagserv).empty?
      (content_tag( :h3, "References")+
       content_tag( :div,
                  tag_info_section( refstrs, label: (label + "'#{@tagserv.name}'" + " on ") ).html_safe,
                  class: "container")).html_safe
    end
  end

  def present_tag_definitions tagserv
    # tagserv.references.where(canonical: true, type: 'DefinitionReference').collect{ |reference| present_reference(reference) }.compact
    tagserv.definition_page_refs.collect { |definition| present_definition(definition) }.compact
  end

  # Return HTML for the links related to a given tag (i.e., the links for 
  # all tags related to this one)
  def present_tag_relations label = 'See Also'
    @tagserv ||= TagServices.new(@tag)
    links =
      Referent.related(@tagserv, false, true).collect { |rel|
        if(rel.id != @tagserv.id)
          refstrs = present_tag_definitions(TagServices.new rel)
          content_tag(:div,
                      tag_info_section(refstrs, label: ("'#{rel.synonyms.map(&:name).join('/&#8201')}'" + " on ")).html_safe,
                      class: "container").html_safe unless refstrs.empty?
        end
      }.compact.join(' | ')
    (content_tag(:h3, label)+links.html_safe) if links
  end

  def present_tag_synonyms label='Synonyms: ', options={}
    if label.is_a?(Hash)
      label, options = 'Synonyms: ', label
    end
    @tagserv ||= TagServices.new(@tag)
    # The synonyms are the other expressions of this tag's referents
    return if (syns = @tagserv.synonyms).empty?
    synstrs = syns.collect { |syn| # homelink syn
      summarize_tag_similar syn, (options[:absorb_btn] && @tagserv.can_absorb(syn))
    }.join('<br>').html_safe
    # tag_info_section synstrs, label: label, joinstr: '<br>'
  end

  def summarize_tag_definition_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.definition_page_ref_count) > 0) ? (pluralize(ct, 'Reference').sub(/\s/, '&nbsp;')+'<br>').html_safe : ''
  end

  def summarize_tag_parents_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.parents.count) > 0) ? (pluralize(ct, 'Parent').sub(/\s/, '&nbsp;')+'<br>').html_safe : ''
  end

  def summarize_tag_children_count
    @tagserv ||= TagServices.new(@tag)
    ((ct = @tagserv.children.count) > 0) ? (pluralize(ct, 'Child').sub(/\s/, '&nbsp;')+'<br>').html_safe : ""
  end

  def summarize_tag_recipe_count
    @tagserv ||= TagServices.new(@tag)
    set = @tagserv.recipe_ids(true)
    count = set.size
    case count
      when 0
      when 1
        homelink Recipe.find(set.first).decorate, title: '1 Recipe'
      else
        (pluralize(count, 'Recipe').sub(/\s/, ' ')+'<br>').html_safe
    end
  end

  def summarize_tag_site_count
    @tagserv ||= TagServices.new(@tag)
    sites = @tagserv.sites
    case sites.count
      when 0
      when 1
        homelink sites.first.decorate, title: '1 Site'
      else
        (pluralize(sites.count, 'Site').sub(/\s/, ' ')+'<br>').html_safe
    end
  end

  def summarize_tag_owner_count
    @tagserv ||= TagServices.new(@tag)
      ct = @tagserv.user_ids.size
      (ct > 0) ? (pluralize(ct, 'Owner').sub(/\s/, '&nbsp;')+'<br>').html_safe : ''
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
    rmv = [Tag.typenum(:Course), Tag.typenum(:List), Tag.typenum(:Epitaph)]
    selections = Tag.type_selections(val.kind_of? Tag).keep_if { |sel| !rmv.include? sel.last }
    selections.insert 3, ['Course', 18]
    selections.first[0] = 'No Type'
    if val.kind_of? Tag
      options_for_select selections, val.typenum
    elsif val.nil?
      options_for_select selections
    else
      options_for_select selections, val
    end
  end

  # Provide a Bootstrap selection menu of a set of tags
  def tag_select alltags, curtags
    menu_options = { class: "question-selector" }
    menu_options[:style] = "display: none;" if (alltags-curtags).empty?
    options = alltags.collect { |tag|
      content_tag :option, tag.name, { value: tag.id, style: ("display: none;" if curtags.include?(tag)) }.compact
    }.unshift(
      content_tag :option, "Pick #{curtags.empty? ? 'a' : 'Another'} Question", value: 0
    ).join.html_safe
    content_tag :select, options, menu_options # , class: "selectpicker"
  end


  def summarize_tag_similar this, other, absorb_btn = false
    contents = [
        homelink(other),
        "(#{other.typename})"
    ]
    contents << button_to_submit('Absorb',
                                 associate_tag_path(this, other: other.id, as: 'absorb', format: 'json'),
                                 :xs,
                                 mode: :modal,
                                 with_form: true,
                                 class: 'absorb_button',
                                 id: "absorb_button_#{other.id}") if absorb_btn
    content_tag :span, safe_join(contents, ' '), class: "absorb_#{other.id}"
  end

  def tag_filter_header locals={}
    locals[:type_selector] ||= false
    render "tags/tag_filter_header", locals # ttl: label, type_selector: type_selector
  end

  def tag_list tags
    strjoin( tags.collect { |tag|
      link_to_dialog tag.name, tag_path(tag)
    }).html_safe
  end

  def list_tags_for_collectible taglist, collectible_decorator=nil
    tags_str = safe_join taglist.collect { |tag|
      link_to_submit tag.name, linkpath(tag), :mode => :partial, :class => 'taglink'
    }, '&nbsp;<span class="tagsep">|</span> '.html_safe
=begin
    collectible_decorator ?
        safe_join( [ tags_str, collectible_tag_button(collectible_decorator)], '&nbsp; '.html_safe ) :
        tags_str
=end
  end
end
