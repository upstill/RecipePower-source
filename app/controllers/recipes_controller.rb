class RecipesController < CollectibleController
  before_filter :allow_iframe, only: :capture
  protect_from_forgery except: :capture

  before_filter :login_required, :except => [:index, :show, :capture, :collect ]
  before_filter { @focus_selector = "#recipe_url" }
    
  filter_access_to :all
  # include ApplicationHelper
  # include ActionView::Helpers::TextHelper
  
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
        if response_service.injector?
          flash[:notice] = notice
          render :errors, locals: { entity: @recipe }
        else
          render :update, locals: { destroyed: destroyed, notice: notice, entity: @recipe }
        end
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
    update_and_decorate
    current_user.touch @recipe if current_user
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
        update_and_decorate (@recipe || Recipe.new)
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
          flash[:popup] = "'#{@recipe.title}' now appearing in your collection."
          render :action => 'collect_and_tag', :mode => :modal
        }
      end
    else # failure (not a valid recipe) => return to new
       response_service.title = "Cookmark a Recipe"
       @nav_current = :addcookmark
       @recipe.url = params[:recipe][:url]
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
            current_user.collect @recipe
            if response_service.injector?
              smartrender :action => :tag
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
          # Defer request, redirecting it for JSON
          login_required :json
        end
      }
      format.json {
        if current_user          
          update_and_decorate Recipe.ensure(params[:recipe]||{}, params[:extractions])
          if @recipe.id && @recipe.errors.empty?
            current_user.collect @recipe
            # Recipe all captured and everything. Let's go tag it.
            smartrender :action => :tag
          else
            render :errors, locals: { entity: @recipe }
          end
        else
          login_required
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

  # Respond to a request from the recipe editor for a list of pictures
  def piclist
      @recipe = Recipe.find(params[:id])
      @piclist = page_piclist @recipe.url
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @piclist }
      end
  end
  
=begin
  def update
    # return if need_login true
    if params[:commit] == "Cancel"
      @recipe = Recipe.find params[:id]
      report_recipe user_collection_url(current_user), "Recipe secure and unchanged.", formats
    else
      update_and_decorate
      if @recipe.errors.empty?
        if ref = @recipe.user_pointers.where( user: current_user ).first
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
=end

  # Register that the recipe was touched by the current user--if they own it.
  def touch
    # This is a generic #touch action except for the manner in which the recipe is fetched
    @entity = Recipe.ensure(params.slice(:id, :url))
    super
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
