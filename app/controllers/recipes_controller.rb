class RecipesController < ApplicationController
  # Return the parameters to link_to for the header's navigation 
  # links, depending on the recipe and controller method
  def navlinks (recipe, request)
    case request
      when :index
        [["Cookmark Another Recipe", new_recipe_path]]
      when :show
        [["Tag", edit_recipe_path(recipe)],
    	["Forget", recipe, 
	   {:method => :delete,
	    :confirm => 'This will remove the recipe from your Cookmarks. That\'s what you want, right??' 
	    }],
	["Cookmarks", recipes_path, 
	   :name=>"Show My Recipe Box"]]
      when :new
    	[["Cookmarks", recipes_path, 
	   :name=>"Show My Cookmark Collection"]]
      when :edit
        [["Forget", recipe, 
	    {:confirm => 'This will remove the recipe from your Cookmarks. That\'s what you want, right??', 
	     :method => :delete}],
	 ["Cookmarks", recipes_path, 
	   :name=>"Show My Cookmark Collection"]]
      when :update
        []
      when :destroy
        []
      when :revise
        []
    end
  end

  def index
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
    @navlinks = navlinks(nil, :index) 
    nav_current = nil
  end

  def show
    return if need_login true
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = session[:user_id]
    @Title = ""
    @navlinks = navlinks(@recipe, :show)
    nav_current = nil
  end

  def new # Collect URL, then redirect to edit
    return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note.
    url = params[:url]
    if url && Recipe.exists?(:url => url)  # Previously captured 
        @recipe = Recipe.where("url = ?", url).first
	@recipe.ensureUser session[:user_id] 
    else
        @recipe = Recipe.new params
	# If it has title and a legitimate URL, get stuff from URL and attach to user
	if @recipe.url
	    # Do QA, trying to save based on the info we have
	    if @recipe.crackURL # Get the picture and title from the foreign site
	        # We may have re-interpreted the URL from the page, so
	        # need to re-check that the recipe doesn't already exist
	        if Recipe.exists? :url=>@recipe.url  # Previously captured 
		    @recipe = Recipe.where("url = ?", @recipe.url).first
	        end
		# All seems well as is, so try to add to user's list
	        @recipe.ensureUser session[:user_id] 
	    end
	end
    end
    if @recipe.id && @recipe.title && !@recipe.title.empty? # Mark of a fetched/successfully saved recipe
	# redirect to edit
	redirect_to edit_recipe_url(@recipe), :notice  => "Successfully cookmarked recipe."
    else
	@Title = "Cookmark a Recipe"
	@navlinks = navlinks(@recipe, :new)
        @nav_current = :addcookmark
	@recipe.current_user = session[:user_id]
    end
  end

  # Action for creating a recipe in response to the the 'new' dialog:
  def create # Take a URL and title, then either lookup or create the recipe
    return if need_login true
    url = params[:recipe][:url]
    if  Recipe.exists? :url => url
        @recipe = Recipe.where("url = ?", url).first
    else
    	@recipe = Recipe.new params[:recipe]
        @recipe.crackURL # Get the picture and title from the foreign site
    end
    # Make sure the recipe is on the user's list (and save)
    @recipe.ensureUser( @recipe.current_user = session[:user_id] ) if @recipe.errors.empty?

    if @recipe.id && !@recipe.title.blank? # Success (valid recipe, either created or fetched)
	    redirect_to edit_recipe_url(@recipe), :notice  => "Recipe Cookmarked!"
    else # failure (not a valid recipe) => return to new
       # No recipe id => try again
       @Title = "Cookmark a Recipe"
       @navlinks = navlinks @recipe, :new
       @nav_current = :addcookmark
       @recipe.current_user = session[:user_id]
       render :action => 'new'
    end
  end

  def edit
    return if need_login true
    # XXX We really should throw an error if the recipe doesn't exist
    @recipe = Recipe.find( id = params[:id].to_i )
    # Forge the connection with the user, if none already
    @recipe.ensureUser( @recipe.current_user = session[:user_id] )

    @Title = "" # Get title from the recipe
    @navlinks = navlinks(@recipe, :edit)
    @nav_current = :addcookmark
    # Now go forth and edit
  end

  def update
    return if need_login true
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = session[:user_id]
    if @recipe.update_attributes(params[:recipe])
      redirect_to rcpqueries_url :notice  => "Successfully updated recipe."
    else
      @Title = ""
      @navlinks = navlinks(@recipe, :edit)
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

    @navlinks = navlinks(@recipe, :destroy)
    redirect_to rcpqueries_url, :notice => "\"#{@recipe.title}\" won't be bothering you any more."
  end

  def revise # modify current recipe to reflect a client-side change
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = session[:user_id]
	# Modification instructions are in query strings:
	# :do => 'add', 'remove'
	# :what => "Genre", "Technique", "Course"
	# :name => string identifier (name of element)
    @navlinks = navlinks(@recipe, :revise)
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
