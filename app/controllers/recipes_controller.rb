require './lib/controller_utils.rb'

class RecipesController < ApplicationController
  before_filter :allow_iframe, only: :capture

  before_filter :login_required, :except => [:index, :show, :capture, :collect ]
  before_filter { @focus_selector = "#recipe_url" }
    
  filter_access_to :all
  include ApplicationHelper
  include ActionView::Helpers::TextHelper
  
  # Render to html, json or js the results of a recipe manipulation
  def report_recipe( url, notice, formats, destroyed = false)
    respond_to do |fmt|
      fmt.html { 
        if response_service.injector? 
          render text: notice
        else
          redirect_to url, :notice  => notice
        end
      }
      fmt.json {
        render :update_collectible_item, locals: { destroyed: destroyed, notice: notice, entity: @recipe }
      }
      fmt.js { 
        render text: @recipe.title 
      }
    end
  end

  def index
    redirect_to collection_path
    # return if need_login true
    # Get the collected recipes for the user named in query
  end

  def show
    # return if need_login true
    @recipe = Recipe.find(params[:id])
    current_user.touch @recipe if current_user
    @decorator = @recipe.decorate
    response_service.title = ""
    @nav_current = nil
    smartrender
  end

  def new # Collect URL, then re-direct to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    if params[:feed_entry]
      # Create the new recipe off the feed entry
      @feed_entry = FeedEntry.find params[:feed_entry].to_i
      params[:url] = @feed_entry.url
    end
    if params[:url] && (@recipe = Recipe.ensure params.slice(:url)) && @recipe.id # Mark of a fetched/successfully saved recipe: it has an id
      current_user.collect @recipe if current_user # Add to the current user's collection
    	# re-direct to edit
    	if @feed_entry
    	  @feed_entry.recipe = @recipe
    	  @feed_entry.save
  	  end
      report_recipe( collection_path, truncate( @recipe.title, :length => 100)+" now appearing in your collection.", formats)
    else
        response_service.title = "Cookmark a Recipe"
        update_and_decorate
        smartrender
    end
  end

  # Action for creating a recipe in response to the the 'new' page:
  def create # Take a URL, then either lookup or create the recipe
    # return if need_login true
    # Find the recipe by URI (possibly correcting same), and bind it to the current user
    update_and_decorate Recipe.ensure(params[:recipe]) # session[:user_id], params[:recipe]
    if @recipe.errors.empty? # Success (valid recipe, either created or fetched)
      current_user.collect @recipe if current_user  # Add to collection
      respond_to do |format|
        format.html { # This is for capturing a new recipe and tagging it using a new page. 
          session[:recipe_pending] = @recipe.id
          redirect_to collection_path
        }
        format.json {
          @data = { onget: [ "submit.submit_and_process", user_collection_url(current_user, layout: false) ] }
          response_service.mode = :modal
          render json: {
            dlog: with_format("html") { 
              render_to_string :edit, layout: false
            }, popup: "'#{@recipe.title}' now appearing in your colleciton."
          }
        }
      end
    else # failure (not a valid recipe) => return to new
       response_service.title = "Cookmark a Recipe"
       @nav_current = :addcookmark
       @recipe.current_user = current_user_or_guest_id # session[:user_id]
       smartrender :action => 'new', mode: :modal 
    end
  end

  def capture # Collect URL from foreign site, asking whether to re-direct to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    respond_to do |format|
      format.html { # This is for capturing a new recipe and tagging it using a new page. 
        if current_user
          update_and_decorate Recipe.ensure(params[:recipe]||{}, params[:extractions])
          if @recipe.id
            current_user.collect @recipe if current_user
            if response_service.injector?
              smartrender :action => :edit 
            else
              # If we're collecting a recipe outside the context of the iframe, redirect to
              # the collection page with an embedded modal dialog invocation
              redirect_to_modal tag_recipe_path(@recipe)
            end
          else
            @resource = @recipe
            render "pages/resource_errors", response_service.render_params
          end
        else
          login_required nil # format: :html, params: params.slice(:recipe, :extractions, :sourcehome )
        end
      }
      format.json {
        if current_user          
          update_and_decorate Recipe.ensure(params[:recipe]||{}, params[:extractions])
          if @recipe.id
            current_user.collect @recipe
            @data = { onget: [ "submit.submit_and_process", user_collection_url(current_user, layout: false) ] } unless response_service.injector?
            # deferred_capture true # Delete the pending recipe
            codestr = with_format("html") { render_to_string :edit, layout: false }
          else
            @resource = @recipe
            codestr = with_format("html") { render_to_string "pages/resource_errors", layout: false } 
          end
          render json: { dlog: codestr }
        else
          # Nobody logged in => 
          response_service.is_injector
          login_required nil # :format => :json, :params => params.slice(:recipe, :extractions, :sourcehome )
        end
      }
      format.js { 
        # Produce javascript in response to the bookmarklet, to build minimal javascript into the host page
        # (from capture.js) which then renders the recipe editor into an iframe, powered by injector.js
        # We need a domain to pass as sourcehome, so the injected iframe can communicate with the browser.
        # This gets extracted from the href passed as a parameter
        response_service.is_injector
        url = URI::encode params[:recipe][:url]
        msg = %Q{"Sorry, but RecipePower can't make sense of the cookmark '#{url}'"}
        begin
          uri = URI(url)
          if uri.host == current_domain.sub(/:\d*/,'') # Compare the host to the current domain (minus the port)
            render js: %Q{alert("Sorry, but RecipePower doesn't cookmark its own pages (does that even make sense?)") ; }
          elsif !(@site = Site.find_or_create(url))
            # If we couldn't even get the site from the domain, we just bail entirely
            render js: %Q{alert(#{msg});}
          else
            params[:recipe][:title] = "Recipe from "+@site.name if params[:recipe][:title].blank?
            @url = capture_recipes_url response_service.redirect_params( params.slice(:recipe).merge sourcehome: @site.domain)
            render
          end
        rescue Exception => e
          render js: %Q{alert(#{msg});}
        end
      }
    end
  end

  def edit
    # return if need_login true
    # Fetch the recipe by id, if possible, and ensure that it's registered with the user
    update_and_decorate 
    if @recipe.errors.empty? # Success (recipe found)
      current_user.collect @recipe if current_user
      response_service.title = @recipe.title.truncate(20) # Get title from the recipe
      @nav_current = nil
      smartrender 
    else
      response_service.title = "Cookmark a Recipe"
      @nav_current = :addcookmark
    end
  end
  
  # Respond to a request from the recipe editor for a list of pictures
  def piclist
      @recipe = Recipe.find(params[:id])
      @piclist = page_piclist @recipe.url
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @piclist }
      end
  end
  
  def update
    # return if need_login true
    if params[:commit] == "Cancel"
      @recipe = Recipe.find params[:id]
      report_recipe user_collection_url(current_user), "Recipe secure and unchanged.", formats
    else
      update_and_decorate
      if @recipe.errors.empty?
        if ref = @recipe.rcprefs.where( user: current_user ).first
          ref.edit_count += 1
          ref.save
        end
        report_recipe( user_collection_url(current_user), "Successfully updated #{@recipe.title || 'recipe'}.", formats )
      else
        response_service.title = "Tag That Recipe (Try Again)!"
        @nav_current = nil
        # render :action => 'edit', :notice => "Huhh??!?"
        # @_area = "page" # params[:_area]
        # Now go forth and edit
        # @_layout = nil # params[:_layout]
        # dialog_boilerplate('edit', 'at_left')
        smartrender :action => 'edit', area: 'at_left'
      end
    end
  end
  
  # Register that the recipe was touched by the current user--if they own it.
  # Since that recipe will now be at the head return a new first-recipe in the list.
  def touch
    update_and_decorate Recipe.ensure(params.slice(:id, :url)) 
    # If all is well, make sure it's on the user's list
    current_user.touch @recipe if current_user && @recipe.errors.empty? && @recipe.id
    respond_to do |format|
      format.json {
          render json: { popup: "Snap! Collected #{@recipe.title}." }
      }
      format.html { 
          @list_name = "mine"
          render 'shared/_recipe_smallpic.html.erb', :layout=>false 
      }
    end
  end

  # Delete the recipe from the user's list
  def uncollect
    update_and_decorate
    current_user.uncollect @recipe if current_user && @recipe.errors.empty?
    @jsondata = {
        replacements: [
            [ "div.rcpGridElmt"+@recipe.id.to_s, "" ]
        ],
        popup: "Fear not. '#{@recipe.title}' has been vanquished from this collection."
    }
    respond_to do |format|
      format.json { render json: @jsondata }
      format.js { render template: "shared/get_content" }
    end
  end

  def remove
    update_and_decorate
    current_user.uncollect @recipe if current_user && @recipe.errors.empty?
    truncated = truncate(@recipe.title, :length => 40)
    report_recipe user_collection_url(@user),
                  "Fear not. \"#{truncated}\" has been vanquished from your cookmarks--though you may see it in other collections.",
                  formats
  end

  # Add a recipe to the user's collection without going to edit tags. Full-page render is just collection page
  # GET recipes/:id/collect
  def collect
    if @user = current_user
      @recipe = Recipe.ensure params
      @list_name = "mine"
      # @_area = params[:_area]
      if @recipe.errors.empty?
        current_user.collect @recipe
        notice = truncate( @recipe.title, :length => 100)+" now appearing in your collection."
        if params[:uid]
          flash[:notice] = notice
          respond_to do |format|
            format.html { redirect_to collection_path }
            format.json { render json: { redirect: collection_path } }
          end
        else
          report_recipe( collection_path, notice, formats)
        end
      else
        respond_to do |format|
          format.html { render nothing: true }
          format.json { render json: { type: :error, popup: @recipe.errors.messages.first.last.last } }
          format.js { render :text => e.message, :status => 403 }
        end
      end
    else # Nobody logged in; defer the collection and render with login dialog
      login_required "You need to be logged in to collect recipes."
    end
  end

  # Remove the recipe from the system entirely
  def destroy
    @recipe = Recipe.find params[:id] 
    title = @recipe.title
    @recipe.destroy
    report_recipe user_collection_url(current_user), "\"#{title}\" is gone for good.", formats, true
  end

  def revise # modify current recipe to reflect a client-side change
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = current_user_or_guest_id # session[:user_id]
	# Modification instructions are in query strings:
	# :do => 'add', 'remove'
	# :what => "Genre", "Technique", "Course"
	# :name => string identifier (name of element)
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
