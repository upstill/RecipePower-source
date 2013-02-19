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
  		else
  			"<p>(Mysterious list element of type #{element.class.to_s})</p>"
  		end
		end
	  flash.now[:message] = @seeker.explain_empty if results.empty?   
		results.join('').html_safe
	end
	
end
