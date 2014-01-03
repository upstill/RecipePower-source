module SeekerHelper
	def seeker_table( heading, query_path, column_heads )
	  header = heading || (@seeker && "<h3>#{@seeker.table_header}</h3>") || ""
	  (%Q{
      #{header}
  		<table class="table table-striped">
  		  <thead>
  		    <tr>
		}+
		column_heads.compact.collect { |header| "<th>#{header}</th>" }.join("\n")+
	  %Q{
  		    </tr>
  		  </thead>
        #{render_seeker_results "tbody", query_path, class: "collection_list"}
  		</table>
  	}).html_safe
  end
  
	# Render an element of a collection, depending on its class
	def render_seeker_item element
		case element
		when Recipe
			@recipe = element
		  @recipe.current_user = @user.id
		  content_tag( :div, 
		    render("shared/recipe_grid"),
		    class: "masonry-item" )
		when FeedEntry
		  @feed_entry = element
		  render "shared/feed_entry"
		else
		  # Default is to set instance variable @<Klass> and render "<klass>s/<klass>"
		  ename = element.class.to_s.downcase
		  self.instance_variable_set("@"+ename, element)
		  render ename.pluralize+"/"+ename 
		end
  end

  # Set up a DOM element to receive a stream of seeker results
	def render_seeker_results enclosing_element, querypath, options={}
    stream_link = link_to "Click to load", "#",
	    # onload: 'RP.stream.go(event);',
	    class: 'content-streamer hidden',
	    data: { kind: @seeker.class.to_s } # , alert: ((current_user && (current_user.id == 3)) ? "Firing Stream" : "") }
    options[:data] ||= {}
    querypath = "/#{querypath}" unless querypath =~ /^\//
    options[:data][:"query-path"] = querypath
    options[:id] = "seeker_results"
    content_tag enclosing_element, stream_link, options
  end

  def element_item selector, elmt
    { elmt: elmt, selector: selector }
  end

  # Package up a collection element for passing into a stream
  def seeker_stream_item element
    elmt = render_seeker_item element
    return { elmt: elmt }
    selector = 
    case element
    when Recipe
      '#masonry-container'
    when FeedEntry
      'ul.feed_entries'
    when Tag
      'tbody.collection_list'
    else
      '.collection_list'
    end
    element_item selector, elmt
  end
end
