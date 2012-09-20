require './lib/controller_utils.rb'

class RecipesController < ApplicationController

  before_filter :login_required, :except => [:index, :show]
  before_filter { @focus_selector = "#recipe_url" }
  
  filter_access_to :all
  include ApplicationHelper
  include ActionView::Helpers::TextHelper

  def index
    redirect_to rcpqueries_url
    # return if need_login true
    # Get the collected recipes for the user named in query
    user = current_user_or_guest 
    @listowner = user.id
    @recipes = user.recipes 
    @Title = "#{user.handle}\'s Cookmarks"
    @nav_current = nil
  end

  def show
    # return if need_login true
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = current_user_or_guest_id # session[:user_id]
    @Title = ""
    @nav_current = nil
    redirect_to @recipe.url
  end

  def new # Collect URL, then redirect to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    
    if params[:url]
        @recipe = Recipe.ensure current_user_or_guest_id, params # session[:user_id], params
    else
        @recipe = Recipe.new
    end
    if @recipe.id # Mark of a fetched/successfully saved recipe: it has an id
    	# redirect to edit
    	redirect_to edit_recipe_url(@recipe), :notice  => "\'#{@recipe.title || 'Recipe'}\' has been cookmarked for you.<br>You might want to confirm the title and picture, and/or tag it?".html_safe
    else
        @Title = "Cookmark a Recipe"
        @nav_current = :addcookmark
        @recipe.current_user = current_user_or_guest_id # session[:user_id]
        respond_to do |format|
          format.html # new.html.erb
          format.json { 
              div = with_format("html") do render_to_string partial: "recipes/fields_new" end
              render json: { dialog: div } 
          }
        end
    end
  end

  # Action for creating a recipe in response to the the 'new' page:
  def create # Take a URL, then either lookup or create the recipe
    # return if need_login true
    # Find the recipe by URI (possibly correcting same), and bind it to the current user
    @recipe = Recipe.ensure current_user_or_guest_id, params[:recipe] # session[:user_id], params[:recipe]
    if @recipe.errors.empty? # Success (valid recipe, either created or fetched)
	    redirect_to edit_recipe_url(@recipe), :notice  => "\'#{@recipe.title || 'Recipe'}\' has been cookmarked for you.<br> You might want to confirm the title and picture, and/or tag it?".html_safe
    else # failure (not a valid recipe) => return to new
       @Title = "Cookmark a Recipe"
       @nav_current = :addcookmark
       render :action => 'new'
    end
  end

  def edit
    # return if need_login true
    # Fetch the recipe by id, if possible, and ensure that it's registered with the user
    @recipe = Recipe.ensure current_user_or_guest_id, params # session[:user_id], params
    if @recipe.errors.empty? # Success (recipe found)
        @recipe.current_user = current_user_or_guest_id # session[:user_id]
        @recipe.touch # We're looking at it, so make it recent
        @Title = @recipe.title # Get title from the recipe
        @nav_current = nil
        @partial = params[:partial]
        # Now go forth and edit
        respond_to do |format|
          format.html {
              if @partial
                render :layout => false
              else
                render :action => 'edit'
              end
          }
          format.json { 
            body = with_format("html") do
              @partial = "at_left"               
              render_to_string :layout => false
            end
            render :json => { dialog: body }
          }
        end
    else
        @Title = "Cookmark a Recipe"
        @nav_current = :addcookmark
    end
  end
  
  # Respond to a request from the recipe editor for a list of pictures
  def piclist
      @recipe = Recipe.find(params[:id])
      @piclist = @recipe.piclist
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @piclist }
      end
  end
  
  def update
    # return if need_login true
    if params[:commit] == "Cancel"
      redirect_to rcpqueries_url :notice  => "Recipe secure and unchanged."
    else
      @recipe = Recipe.find(params[:id])
      @recipe.current_user = current_user_or_guest_id # session[:user_id]
      begin
        debugger
        saved_okay = @recipe.update_attributes(params[:recipe])
        # rescue => e
            # saved_okay = false
            # @recipe.errors.add "Couldn't save recipe"
      end
      if saved_okay
        redirect_to rcpqueries_url :notice  => "Successfully updated #{@recipe.title || 'recipe'}."
      else
        @Title = ""
        @nav_current = nil
        render :action => 'edit', :notice => "Huhh??!?"
      end
    end
  end
  
  # Register that the recipe was touched by the current user--if they own it.
  # Since that recipe will now be at the head return a new first-recipe in the list.
  def touch
      @recipe = Recipe.ensure nil, params # session[:user_id], params
      if @recipe.errors.empty? # Success (recipe found)
          @recipe.current_user = current_user_or_guest_id
          @recipe.touch
      end
      # The client doesn't really care whether we touch successfully or not...
      respond_to do |format|
        list_element_body = render_to_string(:partial => "shared/recipe_smallpic") 
        format.json { 
            render json: { touch_class: touch_date_class(@recipe), 
                           touch_body: touch_date_elmt(@recipe), 
                           list_element_class: recipe_list_element_class(@recipe),
                           list_element_body: list_element_body
                         } 
        }
        format.html { 
            @list_name = "mine"
            render 'shared/_recipe_smallpic.html.erb', :layout=>false 
        }
      end
  end
  
  # Add a recipe to the user's collection without going to edit tags. Full-page render is just rcpqueries page
  # GET recipes/:id/collect
  def collect
    debugger
    @recipe = Recipe.ensure current_user_or_guest_id, params
    @list_name = "mine"
    @partial = params[:partial]
    if @recipe.errors.empty?
      respond_to do |format|
        format.html { 
            if @partial 
                render :partial => "shared/recipe_smallpic", :layout=>false 
            else
                redirect_to rcpqueries_path
            end
        }
        format.json { 
            truncated = truncate @recipe.title, :length => 140
            go_link_body = with_format("html") do render_to_string :partial => "recipes/golink" end
            list_element_body = with_format("html") do render_to_string :partial => "shared/recipe_smallpic" end
            render json: { 
                           type: :element,
                           title: truncated, 
                           go_link_class: recipe_list_element_golink_class(@recipe), 
                           go_link_body: go_link_body,
                           list_element_class: recipe_list_element_class(@recipe), 
                           list_element_body: list_element_body
                         } 
        }
        format.js { render text: @recipe.title }
      end
    else
      respond_to do |format|
        format.html { render nothing: true }
        format.json { render json: { type: :error, error: @recipe.errors.messages.first.last.last } }
        format.js { render :text => e.message, :status => 403 }
      end
    end
  end

  # Delete the recipe from the user's list
  def remove
    # return if need_login true
    @recipe = Recipe.find(params[:id])
    # Simply remove this recipe/user pair from the join table
    user = current_user # User.find(session[:user_id])
    user.recipes.delete @recipe
    user.save
    @recipes = user.recipes(true)
    debugger
    truncated = truncate(@recipe.title, :length => 40)
    redirect_to rcpqueries_url, :notice => "Fear not. \"#{truncated}\" has been vanquished from your cookmarks--though you may see it in other collections."
  end

  # Remove the recipe from the system entirely
  def destroy
    @recipe = Recipe.find(params[:id])
    title = @recipe.title
    @recipe.destroy
    redirect_to rcpqueries_url, :notice => "\"#{title}\" is gone for good."
  end

  def revise # modify current recipe to reflect a client-side change
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = current_user_or_guest_id # session[:user_id]
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
