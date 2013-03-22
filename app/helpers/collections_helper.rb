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
  		when Feed
  		  @feed = element
  		  render "feeds/feed"
  		when User
  		  @user = element
  		  render "users/user"
  		else
  			"<p>(Mysterious list element of type #{element.class.to_s})</p>"
  		end
		end
	  (results.empty? ? 
	   flash_one(:alert, @seeker.explain_empty) : 
	   results.join('')).html_safe
	end
		
	def collection_updater
	  if updated_time = @seeker.updated_at
	    %Q{This feed was last updated #{time_ago_in_words(updated_time)} ago. 
	    #{button_to_update "Check for new entries", "collection/relist", updated_time.to_s} }.html_safe
	  end
	end
end
