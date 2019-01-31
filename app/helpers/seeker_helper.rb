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
        #{arm_seeker_stream "tbody", query_path, class: "collection_list"}
  		</table>
  	}).html_safe
  end
  
	# Render an element of a collection, depending on its class
	def render_seeker_item element
		case element
		when Recipe
			@recipe = element
		  content_tag( :div, 
		    render("show_masonry_item"),
		    class: "masonry-item" )
		when FeedEntry
		  @feed_entry = element
		  render "shared/feed_entry"
		else
		  # Default is to set instance variable @<Klass> and render "<klass>s/<klass>"
		  ename = element.class.to_s.downcase
		  self.instance_variable_set("@"+ename, element)
		  render partial: "#{ename.pluralize}/show_table_item", locals: { ename.to_sym => element }
		end
  end
 
  # Leave a link for stream firing
  def stream_link path, options={}
    options[:onclick] = 'RP.stream.go(event);'
    options[:class] = "#{options[:class]} stream-trigger"
    options[:data] ||= {}
    options[:data][:path] = path
    options[:data][:container_selector] = response_service.container_selector
    link_to "Click to load", "#", options
  end

  # Set up a DOM element to receive a stream of seeker results
  def arm_seeker_stream enclosing_element, querypath, options={}
    link = stream_link "/stream/stream?kind=#{@seeker.class}", class: "content-streamer hidden"
    options[:data] ||= {}
    querypath = "/#{querypath}" unless querypath =~ /^\//
    options[:data][:"query-path"] = querypath
    options[:id] = "seeker_results"
    content_tag enclosing_element, link, options
  end

  def element_item selector, elmt
    { elmt: elmt, selector: selector }
  end

end
