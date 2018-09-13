class CollectibleController < ApplicationController
  before_filter :login_required, :except => [:touch, :index, :show, :associated, :capture, :collect, :card ]
  before_filter :allow_iframe, only: :capture
#  protect_from_forgery except: :capture

  def collect
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      msg = @decorator.title.truncate 50
      if params.has_key? :private
        @decorator.be_collected true
        @decorator.collectible_private = params[:private]
        msg << (@decorator.private ? ' now' : ' no longer')
        msg << ' hidden from others.'
      end
      if params.has_key? :in_collection
        was_collected = @decorator.collectible_collected?
        @decorator.be_collected params[:in_collection]
        @newly_deleted = !(@newly_collected = @decorator.collectible_collected?) if @decorator.collectible_collected? != was_collected
        msg << (@decorator.collectible_collected? ?
            ' now appearing in your collection.' :
            ' has been ousted from your collection (though you may see it elsewhere).')
      end
      @decorator.object.save
      if resource_errors_to_flash(@decorator.object)
        render :errors
      else
        flash[:popup] = msg
        render :collect
      end
    else
      flash[:alert] = 'Sorry, you need to be logged in to collect anything.'
      render :errors
    end
  end

  # Replace the set of lists that the entity is on (as viewed by the current user)
  def lists
    if current_user
      update_and_decorate # Generate a FeedEntryDecorator as @feed_entry and prepares it for editing
      if request.method == 'GET'
        render :lists
      else
        collectible_name = @decorator.title.present? ? @decorator.title.truncate(50) : @decorator.object.model_name.human
        @decorator.object.save
        if resource_errors_to_flash(@decorator.object)
          render :errors
        else
          flash[:popup] = "'#{collectible_name}' treasured."
          render 'collectible/update.json'
        end
      end
    else
      flash[:alert] = 'Sorry, you need to be logged in to manage treasuries.'
      render :errors
    end
  end

  # Extract images, etc from a URL
  def glean
    update_and_decorate
    @what = params[:what].to_sym
    @gleaning =
        if @pageurl = params[:url] # To glean images from another page
          Gleaning.glean @pageurl, 'Image'
        elsif @decorator.object.respond_to?(:gleaning)
          do_force = params[:force] && params[:force] == 'true'
          @decorator.object.page_ref.gleaning = nil if do_force
          @decorator.bkg_land do_force # Wait for gleaning to complete
          if (gl = @decorator.gleaning) && gl.bad?
            @decorator.errors.add :gleaning, "encountered HTTP #{gl.http_status} error: #{gl.err_msg}"
          end
          @decorator.gleaning
        end
    if @gleaning
      if @gleaning.errors.any?
        flash.now[:error] = "Can't extract images from there: #{@gleaning.errors.messages}"
      elsif @gleaning.images.blank?
        flash.now[:error] = 'Sorry, we couldn\'t get any images from that page.'
      else
        flash.now[:success] = 'Images found! Click on an image from the list below to select it.'
      end
    else
      flash.now[:error] = "Gleaning can't be done on #{@decorator.collection_name.gsub '_', ''}"
    end
  end

  def editpic
    update_and_decorate
    @fallback_img = params[:fallback_img]
    gleaning =
    if @pageurl = params[:url]
      Gleaning.glean @pageurl, 'Image'
    elsif @decorator.object.is_a?(Backgroundable) && @decorator.bkg_land
      @decorator.gleaning
    else
      Gleaning.glean @decorator, 'Image'
    end
    @image_list = (gleaning && gleaning.images) ? gleaning.images : []
    if @pageurl && @image_list.blank?
      flash.now[:error] = 'Sorry, we couldn\'t get any images from there.'
      render :errors
    end
  end

  # This method is responsible for attending to the fact that PageRefs are often edited on their own,
  # and perhaps more often presented in the form of an associated recipe or a site
  # When tagging, we will use the associated 'editable_entity', whether that's the PageRef itself,
  # or its proxy.
  #
  # When ASSERTING a tagging (PATCH method), we have to attend to the possibility that the pageref
  # kind was modified. This is tantamount to a SaveAs operation; therefore, we modify the
  # incoming parameters for assigning to the target proxy object.
  #
  # Both of these needs can be satisfied by returning the proxy entity and an appropriate parameters hash,
  # for use by #update_attributes.
  def proxify nominal_entity=nil
    entity_params = params[response_service.controller_model_name]
    case nominal_entity
      when PageRef
        page_ref, prparams = nominal_entity, entity_params
      when Pagerefable
        page_ref, prparams = nominal_entity.page_ref, entity_params[:page_ref_attributes]
      when NilClass
        page_ref, prparams = nil, params[:page_ref] || (entity_params && entity_params[:page_ref_attributes])
      else
        return nominal_entity, entity_params # When no page_ref is involved, keep everything as it was
    end
    # Reconcile the page_ref with any url provided by :extractions parameters
    url = page_ref ? page_ref.url : prparams[:url]
    if params[:extractions]
      url = valid_url(params[:extractions]['URI'], url) || valid_url(params[:extractions]['href'], url) || url
    end
    # Now we compare the submitted page_ref, if any, to the requisite URL
    page_ref = PageRef.fetch(url) unless page_ref && page_ref.answers_to?(url)

    # Take steps if the page_ref is changing kinds
    if prparams && prparams[:kind] && (prparams[:kind] != page_ref.kind)
      # When changing a :recipe page_ref to another type, the associated
      # recipe may have been created gratuitously.
      if page_ref.recipe?
        # Just for the sake of tidiness, when we retype the page_ref from :recipe to something else,
        # and this user is the only one who's collected it, then we destroy it.
        page_ref.recipes.to_a.each { |recipe|
          # Remove any uncollected recipes
          page_ref.recipes.destroy recipe unless (recipe.user_ids - [current_user_or_guest_id]).present?
        }
      end
      page_ref.kind = prparams[:kind]
    end

    # We get an entity--associated with the PageRef--that reflects the possibly new PageRef
    proxy = PageRefServices.new(page_ref).editable_entity nominal_entity, params
    # We're really going to tag the accompanying entity (Site or Recipe)
    # We need to rejigger the parameters so they find their way to the proxy entity.
    return proxy, (nominal_entity || page_ref).decorate.translate_params_for(entity_params, proxy)
  end

  # GET tag
  # PATCH tag
  def tag
    # NB: the PageRefsController handles a GET request to set up tagging, taking params[:extractions] into account
    if current_user
      model, modelparams = proxify response_service.controller_model_class.find_by(id: params[:id])
      modelname = model.model_name.param_key
      misc_tag_tokens = modelparams[:editable_misc_tag_tokens]
      params[modelname] = modelparams.except :editable_misc_tag_tokens
      # Now the parameters should reflect the target type, and we can proceed as usual
      update_and_decorate model, update_attributes: (request.method != 'GET')

      # The editable tag tokens need to be set through the decorator, since Taggable
      # doesn't know what tag types pertain
      @decorator.send @decorator.misc_tags_name_expanded('editable_misc_tag_tokens='), misc_tag_tokens if misc_tag_tokens
      unless @decorator.errors.any? || @decorator.collectible_collected? # Ensure that it's collected before editing
        @decorator.be_collected
        @decorator.save
        flash.now[:notice] = "'#{@decorator.title.truncate(50)}' has been added to your collection for tagging" # if @decorator.object.errors.empty?
      end
      if resource_errors_to_flash @decorator, preface: 'Couldn\'t save.'
        render :errors
      else
        unless request.method == 'GET'
          flash[:popup] = "#{@decorator.human_name} saved"
          render 'collectible/update.json'
        else
          response_service.title = @decorator.title.truncate(20) # Get title (or name, etc.) from the entity
          smartrender
        end
      end
    else
      respond_to do |format|
        format.html {# This is for capturing a new recipe and tagging it using a new page.
          # Defer request, redirecting it for JSON
          login_required :json
        }
        format.json {
          # Not logged in => have to store recipe parameters (url, title, comment) in a safe place pending login
          # session[:pending_recipe] = params[:recipe].merge page_ref_id: page_ref.id
          # After login, we'll be returned to this request to complete tagging
          login_required
        }
      end
    end
  end

  def update
    update_and_decorate
    if resource_errors_to_flash @decorator.object
      render :edit
    else
      # Record gleaning attributes, if available and relevant
      if (model_params = params[@decorator.model_name.param_key]) &&
          @decorator.object.respond_to?(:'gleaning_attributes=')
        @decorator.gleaning_attributes = model_params[:gleaning_attributes]
      end
      flash[:popup] = "#{@decorator.human_name} is saved"
      render :update
    end
  end

  # Register that the entity was touched by the current user.
  # Since that entity will now be at the head return a new first item in the list.
  def touch
    # If all is well, make sure it's on the user's list
    @resource = CollectibleServices.find_or_create(params.slice(:id, :url), response_service.controller_model_class)
    if update_and_decorate(@resource) # May be defined by a subclass before calling up the chain
      who = current_user ||
      if params[:user_id]
        user_id = Rails.application.message_verifier(:touch).verify params[:user_id]
        User.find_by id: user_id
      end
      which_flash = (response_service.format == :html) ? :notice : (who ? :popup : :alert)
      if who
        who.touch @decorator.object, params[:collect]
        verb = @resource.is_a?(User) ? 'Now Following' : 'Collected'
        flash[which_flash] = "Snap! #{verb} '#{@decorator.title}'." if params[:collect]
      else
        flash[which_flash] = "Sorry, you need to be logged in to touch a #{@decorator.human_name}" unless params[:silent]
      end
    end
    resource_errors_to_flash(@decorator.object) if @decorator
    respond_to do |format|
      format.html {
        path_or_object =
          (params[:redirect_external] && ([Recipe, Site, FeedEntry].include? @resource.class.base_class) && @decorator.url.if_present) ||
              view_context.linkpath(@resource)
        redirect_to path_or_object
      }
      format.json { render :errors } # This won't be invoked directly by a user, so there's nothing else to render
    end
  end

  # Absorb another collectible of the same type, denoted by params[:other_id]
  # NB: obviously, this only works if the specific collectible has an absorb method
  def absorb
    if update_and_decorate && params[:other_id] && (other = @decorator.object.class.find(params[:other_id].to_i))
      @absorbee = other.decorate
      @decorator.absorb other
      other.destroy
    end
  end

  def show
    update_and_decorate touch: true
    response_service.title = @decorator && (@decorator.title || '').truncate(20)
    @nav_current = nil
    smartrender
  end

  def associated
    show
  end

  def new # Collect URL, then re-direct to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    if params[:url] &&
        (@resource = CollectibleServices.find_or_create params.slice(:url), response_service.controller_model_class) &&
        @resource.id # A fetched/successfully saved item has an id
      current_user.collect @resource if current_user # Add to the current user's collection
      report_entity( default_next_path, truncate( @resource.decorate.title, :length => 100)+' now appearing in your collection.', formats)
    else
      response_service.title = 'Cookmark a Recipe'
      update_and_decorate (@resource || response_service.controller_model_class.new), touch: true
      smartrender
    end
  end

  # Action for creating a new entity in response to the the 'new' page:
  def create # Take a URL, then either lookup or create the entity
    # return if need_login true
    # Find the recipe by URI (possibly correcting same), and bind it to the current user
    entity, modelparams = proxify
    params[entity.model_name.param_key] = modelparams.except :editable_misc_tag_tokens
=begin
    @resource = CollectibleServices.find_or_create params[response_service.controller_model_name],
                                                 response_service.controller_model_class
=end
    update_and_decorate entity, touch: true, update_attributes: true
    entity.bkg_land # Glean title, etc. as necessary
    if entity.errors.empty? # Success (valid recipe, either created or fetched)
      current_user.collect entity if current_user  # Add to collection
      respond_to do |format|
        format.html { # This is for capturing a new recipe and tagging it using a new page.
          redirect_to default_next_path
        }
        format.json {
          @data = { onget: [ 'submit.submit_and_process', collection_user_url(current_user, layout: false) ] }
          response_service.mode = :modal
          flash[:popup] = "'#{@decorator.title}' now appearing in your collection."
          render :action => 'collect_and_tag', :mode => :modal
        }
      end
    else # failure (not a valid collectible) => return to new
      # Since only url errors will show up in the dialog, add them to the base
      view_context.make_base_errors_except entity, :url
      response_service.title = 'Cookmark a ' + entity.class.to_s
      @nav_current = :addcookmark
      @decorator.url = params[response_service.controller_model_name][:url]
      smartrender :action => 'new', mode: :modal
    end
  end

  def capture # Collect URL from foreign site, asking whether to re-direct to edit
    # return if need_login true
    # Here is where we take a hit on the "Add to RecipePower" widget,
    # and also invoke the 'new cookmark' dialog. The difference is whether
    # parameters are supplied for url, title and note (though only URI is required).
    respond_to do |format|
      format.js {
        # The JS request comes from the bookmarklet. In response, we provide minimal JS to build the
        # Injector dialog.
        # Produce javascript in response to the bookmarklet, to build minimal javascript into the host page
        # (from capture.js) which then renders the recipe editor into an iframe, powered by injector.js
        response_service.is_injector
        begin
          # We need a domain to pass as sourcehome, so the injected iframe can communicate with the browser.
          # This gets extracted from the request referrer or, failing that, the href passed as a parameter
          url = params[:recipe][:url]
          if host_forbidden url # Compare the host to the current domain (minus the port)
            render js: %Q{alert("Sorry, but RecipePower doesn't cookmark its own pages (does that even make sense?)") ; }
          else
            page_ref = PageRef.find_by_url(url) || PageRef.build_by_url(url)
            if page_ref.errors.any?
              msg = page_ref.errors.messages.gsub /\"/, '\''
              render js: %Q{alert("Sorry, but RecipePower can't make sense of this URL (#{msg})") ; }
            else
              # Building the PageRef may lead to a different url than what was passed in
              sourcehome = response_service.referer.if_present || url
              sourcehome = host_url(sourcehome).sub /^https?:/, sourcehome.match(/^https?:/)[0]
              edit_params = response_service.redirect_params.merge sourcehome: sourcehome,
                                                                   page_ref: {
                                                                       url: page_ref.url,
                                                                       kind: page_ref.kind,
                                                                       title: params[:recipe][:title]
                                                                   }.compact
              @url = page_ref.id ? tag_page_ref_url(page_ref, edit_params) : tag_page_refs_url(edit_params)
              @site = page_ref.site
              render
            end
          end
        rescue Exception => e
          render js: %Q{alert("Sorry, but RecipePower can't make sense of the cookmark '#{url}'");}
        end
      }
    end
  end

    # Render to html, json or js the results of a recipe manipulation
  def report_entity(url, notice, formats, destroyed = false)
    respond_to do |fmt|
      fmt.html {
        if response_service.injector?
          render text: notice
        else
          redirect_to url, :notice => notice
        end
      }
      fmt.json {
        if response_service.injector?
          flash[:notice] = notice
          render :errors, locals: {entity: @recipe}
        else
          render :update, locals: {destroyed: destroyed, notice: notice, entity: @recipe}
        end
      }
      fmt.js {
        render text: @recipe.title
      }
    end
  end

end
