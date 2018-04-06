module TagsHelper

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

  # Summarize a tag similar to this one.
  # options:
  #   absorb_btn: a button to absorb the other tag into this one
  #   merge_into_btn: a button to absorb this tag into the other one
  def summarize_tag_similar this, other, options={}
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
                                 id: "absorb_button_#{other.id}") if options[:absorb_btn]
    contents << button_to_submit('Merge Into',
                                 associate_tag_path(this, other: other.id, as: 'merge_into', format: 'json'),
                                 :xs,
                                 mode: :modal,
                                 with_form: true,
                                 class: 'absorb_button',
                                 id: "merge_into_button_#{this.id}") if options[:merge_into_btn]
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
