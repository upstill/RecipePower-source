class RecipesController < ApplicationController

  def index
    redirect_to rcpqueries_url
    return if need_login true
    # Get the collected recipes for the user named in query
    if @listowner = session[:user_id] 
      user = User.find @listowner
      @listownership = (@listowner==session[:user_id] ? 
			"My" : 
			user.username+"\'s").html_safe
      @recipes = user.recipes 
    else
      @listownership = "All the"
      @recipes = Recipe.find(:all)
    end
    @Title = @listownership+" Cookmarks"
    @Title << " in the Whole Wide World" if !@listowner
    @nav_current = nil
  end

  def show
    return if need_login true
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = session[:user_id]
    @Title = ""
    @nav_current = nil
  end

  def new # Collect URL, then redirect to edit
    return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    if params[:url]
        @recipe = Recipe.ensure session[:user_id], params
    else
        @recipe = Recipe.new
    end
    if @recipe.id # Mark of a fetched/successfully saved recipe: it has an id
    	# redirect to edit
    	redirect_to edit_recipe_url(@recipe), :notice  => "\'#{@recipe.title || 'Recipe'}\' has been cookmarked for you.<br>You might want to confirm the title and picture, and/or tag it?".html_safe
    else
        @Title = "Cookmark a Recipe"
        @nav_current = :addcookmark
        @recipe.current_user = session[:user_id]
    end
  end

  # Action for creating a recipe in response to the the 'new' page:
  def create # Take a URL, then either lookup or create the recipe
    return if need_login true
    # Find the recipe by URI (possibly correcting same), and bind it to the current user
    @recipe = Recipe.ensure session[:user_id], params[:recipe]
    if @recipe.errors.empty? # Success (valid recipe, either created or fetched)
	    redirect_to edit_recipe_url(@recipe), :notice  => "\'#{@recipe.title || 'Recipe'}\' has been cookmarked for you.<br> You might want to confirm the title and picture, and/or tag it?".html_safe
    else # failure (not a valid recipe) => return to new
       @Title = "Cookmark a Recipe"
       @nav_current = :addcookmark
       render :action => 'new'
    end
  end

  def edit
    return if need_login true
    # Fetch the recipe by id, if possible, and ensure that it's registered with the user
    @recipe = Recipe.ensure session[:user_id], params
    if @recipe.errors.empty? # Success (recipe found)
        @recipe.current_user = session[:user_id]
        @Title = @recipe.title # Get title from the recipe
        @nav_current = nil
        # Now go forth and edit
    else
        @Title = "Cookmark a Recipe"
        @nav_current = :addcookmark
        render :action => 'new'
    end
  end

  def update
    return if need_login true
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = session[:user_id]
    if @recipe.update_attributes(params[:recipe])
      redirect_to rcpqueries_url :notice  => "Successfully updated #{@recipe.title || 'recipe'}."
    else
      @Title = ""
      @nav_current = nil
      render :action => 'edit'
    end
  end

  def destroy
    return if need_login true
    @recipe = Recipe.find(params[:id])
    # Simply remove this recipe/user pair from the join table
    user = User.find(session[:user_id])
    user.recipes.delete @recipe
    user.save
    @recipes = user.recipes(true)

    redirect_to rcpqueries_url, :notice => "\"#{@recipe.title}\" won't be bothering you any more."
  end

  def revise # modify current recipe to reflect a client-side change
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = session[:user_id]
	# Modification instructions are in query strings:
	# :do => 'add', 'remove'
	# :what => "Genre", "Technique", "Course"
	# :name => string identifier (name of element)
    # @navlinks = navlinks(@recipe, :revise)
    if(params[:do] == "remove") 
    	c = @recipe.tags
    	c.each { |g| c.delete(g) if g.name == params[:name] }
    elsif(params[:do] == "add") 
    	if(params[:what] == "Tags")
    	end
    end
    render :text => params[:name]
    return true
  end

  # parse a recipe fragment, tagging it with the named class and (possibly)
  #  looking for substrings to match
  def parse
      # In general the text is free of HTML formatting, except that 1) presumably
      # spans denoting microformat data are preserved, and 2) prior
      # calls to parse sections may have left spans behind
      words = params[:html]
      result = Recipe.parse words, params[:class]

      # For now, just return the text as sent
      render :text => result
  end
end
