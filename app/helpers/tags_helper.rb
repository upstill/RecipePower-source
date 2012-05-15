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
        ct = tag.recipe_ids.size
        (ct > 0) ? pluralize(ct, "Recipe") : ""
    end
        
    def count_owners tag
        ct = tag.user_ids.size
        (ct > 0) ? pluralize(ct, "Owner") : ""
    end
        
    def count_links tag
        ct = tag.link_ids.size
        (ct > 0) ? pluralize(ct, "Link") : ""
    end
        
    def summarize_synonyms tag
        # The synonyms are the other expressions of this tag's referents
        ids = tag.referents.collect { |ref| ref.tag_ids }.flatten.uniq.delete_if { |id| id == tag.id }
        ids.empty? ? "" : ids.collect { |id| Tag.find(id).name+"(#{id.to_s})" }.join(', ').html_safe
    end
    
    def summarize_tag tag, withtype = false
	    ((withtype ? "<i>#{tag.typename}</i> " : "" )+
        "'<strong>#{tag.name}</strong>'").html_safe
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
   def type_selections tag
       options_for_select(Tag.type_selections, tag.typenum )
   end
       
  # Return HTML for the links associated with this tag
   def summarize_tag_links tag, label = "See: "
     if tag.link_ids.size > 0
       ("<hr><br>#{label}#{tag.name} %> on:"+
       tag.links.collect{ |link| present_link link }.join(', ')).html_safe
     end
   end
       
  # Return HTML for the links related to a given tag (i.e., the links for 
  # all tags related to this one)
  def summarize_tag_relations tag
    links = Referent.related(tag, true, true).collect { |rel| summarize_tag_links rel, "" }.keep_if{|s| s}
    ("<hr><br>See Also: "+links.join('<br')).html_safe unless links.empty?
  end
  
  def summarize_tag_owners tag
      ("<br>Is owned by "+
        (tag.isGlobal ? 
        "everyone" :
        ("<br>&nbsp;"+tag.users.collect { |user| user.username }.join(',<br>&nbsp;')))).html_safe
  end
  
  # Helper for showing the tags which are potentially redundant wrt. this tag:
  # They match in the normalized_name field
  def summarize_tag_similars tag, label=" Similar tags: "
      others = Tag.where(normalized_name: tag.normalized_name).delete_if{ |other| other.id == tag.id }
      unless others.empty? 
          ("<br>"+
          others.collect { |other| link_to( other.name, other)+"(#{other.typename} #{other.id.to_s})" }.join(', ')).html_safe
      end
  end
end
