module TagsHelper
    
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
    
    def summarize_tag tag
        "<strong>#{tag.name}</strong>".html_safe
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
   	    while type = Tag.index_to_type(ix) # we get nil when we've run off the end of the table
   	        label = Tag.typename(type).to_s.pluralize
   	        tabstrs += <<BLOCK_END
       		    <li class="tag_tab"><a href="tags/list?tabindex=#{ix.to_s}" title="#{label}">#{label}</a></li> 
BLOCK_END
   	        ix += 1
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
end
