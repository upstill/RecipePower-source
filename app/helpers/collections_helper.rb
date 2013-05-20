module CollectionsHelper
  
	def collection_results
	  results =
		@seeker.results_paged.collect do |element|
  		case element
  		when Recipe
  			@recipe = element
  		  @recipe.current_user = @user_id
  		  render "shared/recipe_grid"
  		when FeedEntry
  		  @feed_entry = element
  		  render "shared/feed_entry"
=begin
  		when Feed
  		  @feed = element
  		  render "feeds/feed"
  		when User
  		  @user = element
  		  render "users/user"
  		when Reference
  		  @reference = element
  		  render "references/reference"
  		when Tag
  		  @tag = element
  		  render "tags/tag"
=end
  		else
  		  # Default is to set instance variable @<Klass> and render "<klass>s/<klass>"
  		  ename = element.class.to_s.downcase
  		  self.instance_variable_set("@"+ename, element)
  		  render ename.pluralize+"/"+ename 
  		end
		end
	  flash.now[:alert] = @seeker.explain_empty if results.empty?  
	  results.join('').html_safe
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
