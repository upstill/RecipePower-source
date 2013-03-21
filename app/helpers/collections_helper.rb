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
	
	# Return the updated_at time for the collection, for update purposes
	def collection_timestamp
	  @seeker.updated_at.to_s
  end
	
end
