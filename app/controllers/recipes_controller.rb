class RecipesController < CollectibleController

  before_filter :login_required, :except => [:index, :show, :associated, :capture, :collect ]
  before_filter { @focus_selector = '#recipe_url' }
    
  filter_access_to :all
  # include ApplicationHelper
  # include ActionView::Helpers::TextHelper

=begin
  def capture # Collect URL from foreign site, asking whether to re-direct to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    x=2
    respond_to do |format|
      format.html { # This is for capturing a new recipe and tagging it using a new page.
        if current_user
          @resource = CollectibleServices.find_or_create params[response_service.controller_model_name]||{},
                                                         params[:extractions],
                                                         response_service.controller_model_class
          update_and_decorate @resource, true
          if @resource.id
            current_user.collect @resource
            if response_service.injector?
              smartrender :action => :tag
            else
              # If we're collecting a recipe outside the context of the iframe, redirect to
              # the collection page with an embedded modal dialog invocation
              tag_path = polymorphic_path [:tag, @resource]
              redirect_to_modal tag_path
            end
          else
            render 'pages/resource_errors', response_service.render_params
          end
        else
          # Defer request, redirecting it for JSON
          login_required :json
        end
      }
      format.json {
        if current_user
          @resource = CollectibleServices.find_or_create params[response_service.controller_model_name]||{},
                                                         params[:extractions],
                                                         response_service.controller_model_class
          update_and_decorate @resource, true
          if @resource.id && @resource.errors.empty?
            current_user.collect @resource
            # Recipe all captured and everything. Let's go tag it.
            smartrender :action => :tag
          else
            render :errors, locals: { entity: @resource }
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
        uri = URI(params[:recipe][:url])
        sourcehome = "#{uri.scheme}://#{uri.host}"
        url = uri.to_s
        msg = %Q{"Sorry, but RecipePower won't make sense of the cookmark '#{url}'"}
        begin
          if host_forbidden url # Compare the host to the current domain (minus the port)
            render js: %Q{alert("Sorry, but RecipePower doesn't cookmark its own pages (does that even make sense?)") ; }
          elsif !(@site = Site.find_or_create(url))
            # If we couldn't even get the site from the domain, we just bail entirely
            render js: %Q{alert(#{msg});}
          else
            params[:recipe][:title] = 'Recipe from '+@site.name if params[:recipe][:title].blank?
            @url = capture_recipes_url response_service.redirect_params( params.slice(:recipe).merge sourcehome: sourcehome)
            render
          end
        rescue Exception => e
          render js: %Q{alert(#{msg});}
        end
      }
    end
  end
=end

  def capture
    super
  end

  def index
    redirect_to default_next_path
    # return if need_login true
    # Get the collected recipes for the user named in query
  end

  def revise # modify current recipe to reflect a client-side change
    @recipe = Recipe.find(params[:id])
    @recipe.current_user = current_user_or_guest_id # session[:user_id]
	# Modification instructions are in query strings:
	# :do => 'add', 'remove'
	# :what => "Genre", "Technique", "Course"
	# :name => string identifier (name of element)
    if(params[:do] == 'remove')
    	c = @recipe.tags
    	c.each { |g| c.delete(g) if g.name == params[:name] }
    elsif(params[:do] == 'add')
    	if(params[:what] == 'Tags')
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
