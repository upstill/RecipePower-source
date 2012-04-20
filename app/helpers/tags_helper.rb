module TagsHelper
    def summarize_tags(tags)
	tags.collect{|e| "<strong>#{e.name}</strong>" }.join(', ')
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
       		    <li class="tag_tab"><a href="tags/editor?tabindex=#{ix.to_s}" title="#{label}">#{label}</a></li> 
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
