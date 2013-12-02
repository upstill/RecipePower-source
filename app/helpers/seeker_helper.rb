module SeekerHelper
	def seeker_table( heading, column_heads )
	  header = heading || "<h3>#{@seeker.table_header}</h3>"
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
  		  <tbody class="collection_list">
  				#{render_seeker_results}
  		  </tbody>
  		</table>
  	}+
  	render("shared/paginate_list")
  	).html_safe
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
  
	def render_seeker_results
	  return link_to "Click to load", "#",
	    onload: 'RP.stream.go(event);',
	    class: 'content-streamer hidden',
	    data: { kind: @seeker.class.to_s }
    return %q{<div class='streamer' onready="RP.stream.go(event);">Hang on a second...</div>}.html_safe
	  page =
	  time_check_log("render_seeker_results acquiring") do
  	  @seeker.results_paged
  	end
	  tstart = Time.now
	  results = time_check_log("render_seeker_results rendering #{page.count.to_s} items") do
  		page.collect do |element|
  		  render_seeker_item element
  		end
		end
	  results.join('').html_safe
  end

  def element_item selector, elmt
    { elmt: elmt, selector: selector }
  end

  # Package up a collection element for passing into a stream
  def seeker_stream_item element
    elmt = render_seeker_item element
    selector = 
    case element
    when Recipe
      '#masonry-container'
    when FeedEntry
      'ul.feed_entries'
    else
      '.collection_list'
    end
    element_item selector, elmt
  end
end
