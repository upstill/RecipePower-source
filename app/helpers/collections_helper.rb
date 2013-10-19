module CollectionsHelper
require "time_check"
	
	# Render an element of a collection, depending on its class
	def collection_element element
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
  
	def collection_results
	  return "".html_safe
	  page = 
	  time_check_log("collection_results acquiring") do
  	  @seeker.results_paged
  	end
	  tstart = Time.now
	  results = time_check_log("collection_results rendering #{page.count.to_s} items") do
  		page.collect do |element|
  		  collection_element element
  		end
		end
	  flash.now[:alert] = @seeker.explain_empty if results.empty?  
	  results.join('').html_safe
	end
	
	def collection_itemtitle
	  ttl = @node.guide(false)
	  @node.selected ? "" : %Q{title="#{ttl}"}
  end
		
	def collection_updater
	  if updated_time = @seeker.updated_at
	    content_tag :div, 
	                ["This feed was last updated", 
	                  time_ago_in_words(updated_time), 
	                  "ago.", 
	                  button_to_update("Check for new entries", "collection/relist", updated_time.to_s, msg_selector: "div.updater")].join(' ').html_safe,
	                class: "updater"
	  end
	end
end
