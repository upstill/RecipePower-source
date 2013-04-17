require './lib/controller_utils.rb'

class RecipesController < ApplicationController

  before_filter :login_required, :except => [:index, :show, :capture ]
  before_filter { @focus_selector = "#recipe_url" }
  skip_before_filter :setup_collection, :only => [:capture]
    
  filter_access_to :all
  include ApplicationHelper
  include ActionView::Helpers::TextHelper
  
  # Render to html, json or js the results of a recipe manipulation
  def report_recipe( url, notice, formats, destroyed = false)
    truncated = truncate @recipe.title, :length => 140
    respond_to do |fmt|
      fmt.html { 
        if (params[:layout] && params[:layout] == "injector")
          render text: notice
        else
          redirect_to url, :notice  => notice
        end
      }
      fmt.json { 
        replacements = [
          [ "."+recipe_list_element_golink_class(@recipe) ], 
          [ "."+recipe_list_element_class(@recipe) ], 
          [ "."+recipe_grid_element_class(@recipe) ] 
        ]
        replacements << [ "."+feed_list_element_class(@feed_entry) ] if @feed_entry
        if current_user.browser.should_show(@recipe) && !destroyed
          replacements[0][1] = with_format("html") do render_to_string :partial => "recipes/golink" end
          replacements[1][1] = with_format("html") do render_to_string :partial => "shared/recipe_smallpic" end
          replacements[2][1] = with_format("html") do render_to_string :partial => "shared/recipe_grid" end
          replacements[3][1] = with_format("html") do render_to_string :partial => "shared/feed_entry" end if @feed_entry
        end
        render json: { 
                       done: true, # Denotes recipe-editing is finished
                       popup_msg: notice,
                       title: truncated, 
                       replacements: replacements,
                       action: params[:action],
                       processorFcn: "RP.rcp_list.update"
                     } 
      }
      fmt.js { 
        render text: @recipe.title 
      }
    end
  end

  def index
    redirect_to collection_url
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
    if params[:feed_entry]
      # Create the new recipe off the feed entry
      @feed_entry = FeedEntry.find params[:feed_entry].to_i
      params[:url] = @feed_entry.url
    end
    @recipe = Recipe.ensure current_user_or_guest_id, params.slice(:url) # session[:user_id], params
    if @recipe.id # Mark of a fetched/successfully saved recipe: it has an id
    	# redirect to edit
    	if @feed_entry
    	  @feed_entry.recipe = @recipe
    	  @feed_entry.save
  	  end
      report_recipe( collection_path, truncate( @recipe.title, :length => 100)+" now appearing in your collection.", formats)
    	# redirect_to edit_recipe_url(@recipe), :notice  => "\'#{@recipe.title || 'Recipe'}\' has been cookmarked for you.<br>You might want to confirm the title and picture, and/or tag it?".html_safe
    else
        @Title = "Cookmark a Recipe"
        @nav_current = :addcookmark
        @recipe.current_user = current_user_or_guest_id # session[:user_id]
        @area = params[:area]
        dialog_boilerplate 'new', 'modal'
    end
  end

  def capture # Collect URL from foreign site, asking whether to redirect to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    @area = params[:area] || "at_top"
  	dialog_only = params[:how] == "modal" || params[:how] == "modeless"
    respond_to do |format|
      format.html { # This is for capturing a new recipe and tagging it using a new page. 
        @recipe = Recipe.ensure current_user_or_guest_id, params[:recipe] # session[:user_id], params
        # The injector (capture.js) calls for this to fill the iframe on the foreign page.
        @layout = "injector"
        if @recipe.id
          if params[:area]
            render :edit, :layout => (params[:layout] || dialog_only)
          else
            # If we're collecting a recipe outside the context of the iframe, just
            # redirect back to the recipe. We can't edit the recipe, but too bad.
            redirect_to @recipe.url
          end
        else
          @resource = @recipe
          render "pages/resource_errors", :layout => (params[:layout] || dialog_only)
        end
      }
      format.json {
        @recipe = Recipe.ensure current_user_or_guest_id, params[:recipe] # session[:user_id], params
        if @recipe.id
          codestr = with_format("html") { render_to_string :edit, layout: false }
        else
          @resource = @recipe
          codestr = with_format("html") { render_to_string "pages/resource_errors", layout: false } 
        end
        render json: { code: codestr }
      }
      format.js { 
        # Produce javascript in response to the bookmarklet, to render into an iframe, 
        # either the recipe editor or a login screen.
        # We need a domain to pass as sourcehome, so the injected iframe can communicate with the browser
        params[:recipe][:url].strip!
        if uri = URI::HTTP.sans_query(params[:recipe][:url])
          domain = uri.scheme+"://"+uri.host
          domain += ":"+uri.port.to_s if uri.port != 80
          @url = capture_recipes_url area: "at_top", layout: "injector", recipe: params[:recipe], sourcehome: domain
          if !current_user # Apparently there's no way to check up on a user without hitting the database
            # Push the editing URL so authentication happens first
            session[:original_uri] = @url
            @url = new_authentication_url area: "at_top", layout: "injector", sourcehome: domain 
          end
        end
        render
      }
    end
  end

  def edit
    # return if need_login true
    # Fetch the recipe by id, if possible, and ensure that it's registered with the user
    @recipe = Recipe.ensure current_user_or_guest_id, params.slice(:id) # session[:user_id], params
    if @recipe && @recipe.errors.empty? # Success (recipe found)
      @Title = @recipe.title # Get title from the recipe
      if params[:pic_picker]
        # Setting the pic_picker param requests a picture-editing dialog
        render :partial=> "shared/pic_picker"
      else
        @nav_current = nil
        @area = params[:area]
        # Now go forth and edit
        @layout = params[:layout]
        dialog_boilerplate('edit', 'at_left')
      end
    else
      @Title = "Cookmark a Recipe"
      @nav_current = :addcookmark
    end
  end

  # Action for creating a recipe in response to the the 'new' page:
  def create # Take a URL, then either lookup or create the recipe
    # return if need_login true
    # Find the recipe by URI (possibly correcting same), and bind it to the current user
    @recipe = Recipe.ensure current_user_or_guest_id, params[:recipe] # session[:user_id], params[:recipe]
    if @recipe.errors.empty? # Success (valid recipe, either created or fetched)
      report_recipe(  
        edit_recipe_url(@recipe), 
        "\'#{@recipe.title || 'Recipe'}\' has been cookmarked for you.<br> You might want to confirm the title and picture, and/or tag it?".html_safe,
        formats )
    else # failure (not a valid recipe) => return to new
       @Title = "Cookmark a Recipe"
       @nav_current = :addcookmark
       render :action => 'new'
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
    @recipe = Recipe.find(params[:id])
    if params[:commit] == "Cancel"
      report_recipe collection_url, "Recipe secure and unchanged.", formats
    else
      @recipe.current_user = current_user_or_guest_id # session[:user_id]
      begin
        saved_okay = @recipe.update_attributes(params[:recipe])
        # rescue => e
            # saved_okay = false
            # @recipe.errors.add "Couldn't save recipe"
      end
      if saved_okay
        report_recipe( collection_url, "Successfully updated #{@recipe.title || 'recipe'}.", formats )
      else
        @Title = "Tag That Recipe (Try Again)!"
        @nav_current = nil
        # render :action => 'edit', :notice => "Huhh??!?"
        @area = "page" # params[:area]
        # Now go forth and edit
        @layout = nil # params[:layout]
        dialog_boilerplate('edit', 'at_left')
      end
    end
  end
  
  # Register that the recipe was touched by the current user--if they own it.
  # Since that recipe will now be at the head return a new first-recipe in the list.
  def touch
    @recipe = Recipe.ensure current_user_or_guest_id, params.slice(:id, :url), false # session[:user_id], params
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
    @recipe = Recipe.ensure current_user_or_guest_id, params
    @list_name = "mine"
    @area = params[:area]
    if @recipe.errors.empty?
      report_recipe( collection_path, truncate( @recipe.title, :length => 100)+" now appearing in your collection.", formats)
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
    @recipe = Recipe.ensure current_user_or_guest_id, params.slice(:id), false
    @recipe.remove_from_collection current_user_or_guest_id
    truncated = truncate(@recipe.title, :length => 40)
    report_recipe collection_url, 
      "Fear not. \"#{truncated}\" has been vanquished from your cookmarks--though you may see it in other collections.", 
      formats
    # redirect_to collection_url, :notice => "Fear not. \"#{truncated}\" has been vanquished from your cookmarks--though you may see it in other collections."
  end

  # Remove the recipe from the system entirely
  def destroy
    @recipe = Recipe.find params[:id] 
    title = @recipe.title
    @recipe.destroy
    report_recipe collection_url, "\"#{title}\" is gone for good.", formats, true
    # redirect_to collection_url, :notice => "\"#{title}\" is gone for good."
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
