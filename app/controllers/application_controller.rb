require './lib/templateer.rb'
require './lib/nested_benchmark.rb'
require 'rp_event'
require 'reloader/sse'
require 'results_cache.rb'
require 'filtered_presenter.rb'

class ApplicationController < ActionController::Base
  include Pundit
  include ControllerUtils
  include Querytags # Grab the query tags from params for filtering a list
  include ActionController::Live   # For streaming
  protect_from_forgery with: :exception

  # All controller actions are preceded by a check for permissions
  # This method may be subclassed to assert opt-ins and exclusions
  def check_credentials opts = {}
    return if opts[:only] && !opts[:only].include?(params[:action])
    unless opts[:except]&.include?(params[:action])
      target_model_name = controller_name.classify
      model_class_or_name = begin
        target_model_name.constantize
      rescue
        :"#{target_model_name.underscore}"
      end
      authorize model_class_or_name
    end
  end

  def self.filter_access_to *args
    # TODO: remove this
    # We have to declare a bogus before_action so filter_access_to can remove it without error
    before_action { true }
    # before_action :filter_access_filter
    # super *args
  end
  before_action :check_credentials
  before_action :check_flash
  before_action :report_cookie_string
  before_action { report_session 'Before controller' }
  before_action :set_current_user
  # after_action :log_serve
  after_action { report_session 'After controller'  }
  before_action :setup_response_service

  helper :all
  rescue_from Timeout::Error, :with => :timeout_error # self defined exception
  rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
  rescue_from AbstractController::ActionNotFound, :with => :no_action_error

  helper_method :response_service
  helper_method :orphantagid
  helper_method :default_next_path
  # Supplied by ControllerDeference
  helper_method :pending_modal_trigger

  # From ControllerUtils
  helper_method :express_error_context
  helper_method :resource_errors_to_flash
  helper_method :resource_errors_to_flash_now
  helper_method :with_format
  # helper_method :'permitted_to?'

  include ApplicationHelper

  # The current user is frequently a factor in model machinations (for example, setting comments,
  # which happens in a Collectible's associated Rcpref). The solution is to make the current user
  # a (thread-safe) class attribute
  def set_current_user
    User.current = current_user
  end

  def edit
    update_and_decorate
    smartrender
  end

  # Generic action for approving an entity
  def approve
    update_and_decorate
    @decorator.approved = params[:approve] == 'Y'
    @decorator.save
    flash[:popup] = 'Thumbs '+(@decorator.approved ? 'Up' : 'Down')
  end

  # Generic action for destroying an entity
  def destroy
    if update_and_decorate
      @decorator.destroy
      if @decorator.errors.any? # resource_errors_to_flash(@decorator.object)
        render :errors, locals: { entity: @decorator.object }
      else
        flash[:popup] ||= "#{@decorator.human_name} is no more."
        render :update
      end
    else
      flash[:alert] = "Can't locate #{params[:controller].singularize} ##{params[:id] || '<unknown>'}"
      render :errors
    end
  end

  # Simple path to remove a pending invitation (can still be re-invoked later)
  def defer_invitation
    response_service.invitation_token = nil
  end

  # Generate a navtab menu as denoted by params[which]
  # NB: JSON ONLY!!!
  def menu
    respond_to do |format|
      format.json do
        if %w{ collections friends my_lists feeds home }.include? params[:which]
          render json: { replacements: [ navmenu_replacement(params[:which].to_sym) ] }.to_json, :content_type => 'application/json'
        else
          flash[:alert] = "Unknown menu type '#{params[:which]}'"
          render :errors
        end
      end
    end
  end

  # Set up a model for editing or rendering. The parameters are orthogonal:
  # If entity is nil, it is either fetched using params[:id] or created anew
  # If attribute_params are non-nil, they are used to initialize(update) the created(fetched) entity
  # We also setup an instance variable for the entity according to its class,
  #  and also set up a decorator (@decorator) on the entity
  # options:
  #    :update_attributes: if true, update the object's attributes
  #    :attribute_params: parameters for updating the object (optional)
  #    :action_authorized asserts that the user is authorized
  #    :touch: if true, touch the object in question
  # Return value: true if all is well
  def update_and_decorate entity=nil, options={}
    if entity.is_a? Hash
      entity, options = nil, entity
    end
    if entity.is_a? Draper::Decorator
      @decorator = entity
      entity = entity.object
    end
    # Finish whatever background task is associated with the entity
    entity.bkg_land if entity.is_a?(Backgroundable) && entity.dj
    attribute_params =
    if entity
      # If the entity is provided, ignore parameters
      (options[:attribute_params] || strong_parameters) if options[:update_attributes]
    else # If entity not provided, find/build it and update attributes
      objclass = params[:controller].singularize.camelize.constantize
      entity = params[:id] ? objclass.find(params[:id]) : objclass.new
      (options[:attribute_params] || strong_parameters)
    end
    # The entity has been defined. Now to check that the user is authorized for the current action
    # NB: Since this method may be called in any context, it's possible to assert authorization
    options[:action_authorized] || authorize(entity) # Make sure that the user is authorized for this action
    if entity.errors.empty?  &&  # No probs. so far
        entity.is_a?(Collectible) &&
        current_user # Only the current user gets to touch/modify a model
      case options[:touch]
      when true
        entity.be_touched
      when false
        # Do not touch
      when :collect # Add it to the collection
        entity.be_collected
      when nil
        # Touch iff previously persisted (i.e., don't add record)
        entity.be_touched if entity.persisted?
      end
      if attribute_params.present? # There are parameters to update
        entity.update_attributes attribute_params
      elsif entity.persisted? # If not, look at saving the toucher_pointer
        entity.save
      end
    end
    # Having prep'ed the entity, set instance variables for the entity and decorator
    instance_variable_set :"@#{entity.model_name.singular}", entity
    # We build a decorator if necessary and possible
    unless (@decorator && entity == @decorator.object) # Leave the current decorator alone if it will do
      @decorator = (entity.decorate if entity.respond_to? :decorate)
    end
    if entity.respond_to? :title
      response_service.title = (entity.title || '').truncate(20)
    elsif @decorator && @decorator.respond_to?(:title)
      response_service.title = (@decorator.title || '').truncate(20)
    end
    @presenter = present(entity) rescue nil # Produce a presenter if possible
    entity.errors.empty? # ...and report back status
  end

  # Get the model parameters as filtered by strong parameters for the current controller
  # This is a skin on #<model>_params as defined by each controller to constrain mass assignment
  #
  # If #<model>_params is NOT defined in the controller, we simply return the parameters for the model
  def strong_parameters modelname = params[:controller].singularize
    method_name = "#{modelname}_params"
    # logger.debug "Getting strong parameters for controller #{params[:controller]}"
    # Check for the presence of the model's params
    return {} unless params[modelname].present?

    # Get the params from the controller's #<modelname>_params method, if any
    # logger.debug "...trying #{method_name}"
    return self.send(method_name) if self.respond_to? method_name, true # Allow for private params method

    # Try to call <ModelClass>.mass_assignable_attributes
    mc = modelname.camelize.constantize
    # logger.debug "...trying to get mass_assignable_attributes from #{mc.to_s}"
    return params.require(modelname).permit(mc.mass_assignable_attributes) if mc.respond_to? :mass_assignable_attributes

    # Finally just return the params if nothing else
    # logger.debug "...giving up and returning params[#{modelname}]"
    params.require(modelname).permit # Good luck with that!
  end

  # This replaces the old collections path, providing a path to either the current user's collection or home
  def default_next_path
    # current_user ? collection_user_path(current_user) : home_path
    current_user ? user_path(current_user) : home_path
  end

  # Get a presenter for the object from within a controller
  # TODO Should we be detecting a presenter on the subclass if such?
  def present object
    "#{object.class.base_class.to_s}Presenter".constantize.new object, view_context
  end

  def check_flash
    flash.now[:notice] = params[:notice] if params[:notice]
    flash.now[:error] = params[:error] if params[:error]
    if params[:flash]
      params[:flash].each { |k, v| flash.now[k.to_sym] = v }
    end
    logger.debug "FLASH messages extant for #{params[:controller]}##{params[:action]} (check_flash):"
    flash.each { |type, message| logger.debug "   #{type}: #{message}" }
  end

  def report_cookie_string
    logger.info "COOKIE_STRING:"
    if cs = request.env["rack.request.cookie_string"]
      cs.split('; ').each { |str| logger.info "\t"+str }
    end
  end

  def report_session context
    logger.info "XXXXXXXXXXXXXXXX #{context} at #{Time.now}: XXXXXXXXXXXXXXXX"
    logger.info "COOKIES: >>>>>>>>"
    response.cookies.each { |k, v| logger.info "#{k}: #{v}" }
    logger.info "<<<<<<<< COOKIES"
    begin
      sessid = if session
        (session.is_a?(Hash) ? session[:id] : (session.id if session.respond_to?(:id))) || '<SESSION with no id>'
      else
        '<NO SESSION>'
      end
      logger.info "SESSION id: #{sessid}"
    rescue Exception => e
      logger.debug "DANGER! Accessing session caused error '#{e}'"
    end
    logger.info "SESSION Contents: >>>>>>>>"
    if sess = request.env['rack.session']
                  sess.keys.each { |key| logger.info "\t#{key}: '#{sess[key]}'"}
    else
      logger.info "NO env['rack.session']!!!"
    end
    logger.info "<<<<<<<< SESSION"
    logger.info "UUID: #{response_service.uuid}"
  end

  # Monkey-patch to adjudicate between streaming and render_to_stream per
  # http://blog.sorah.jp/2013/07/28/render_to_string-in-ac-live
  def render_to_string(*)
    orig_stream = response.stream
    super
  ensure
    if orig_stream
      response.instance_variable_set(:@stream, orig_stream)
    end
  end

  # Generalized response for dialog for a particular area
  def smartrender renderopts={}
    NestedBenchmark.measure 'smartrender' do
      response_service.action = renderopts[:action] || params[:action]
      url = renderopts[:url] || request.original_url
      renderopts = response_service.render_params renderopts
      # Give the stream a crack at it
      if fp = NestedBenchmark.measure('Building FilteredPresenter') do
        FilteredPresenter.build view_context,
                                response_service,
                                response_service.params_hash.merge(admin_view: response_service.admin_view?),
                                @decorator
      end
        NestedBenchmark.measure "Rendering #{fp.class}" do
          render_fp fp
        end
      else
        respond_to do |format|
          format.html do
            if response_service.mode == :modal
              # Run the request as a dialog within the home or collection page
              redirect_to_modal url, renderopts[:modal_page]
            else
              render response_service.action, renderopts
            end
          end
          format.json {
            case response_service.mode
              when :modal, :injector
                dialog = render_to_string renderopts.merge(action: response_service.action, layout: (@layout || false), formats: ['html'])
                render json: {dlog: dialog, how: 'bootstrap'}.to_json, layout: false, :content_type => 'application/json'
              else
                # Render a replacement for the pagelet partial, as if it were rendered on the page
                render partial: 'layouts/pagelet' # Respond with JSON instructions to replace the pagelet appropriately
            end
          }
          format.js {
            # XXX??? Must have set @partial in preparation
            render renderopts.merge(action: 'capture')
          }
        end
      end
    end
  end

# Use the filtered_presenter to render various aspects of a page--including streaming items
  def render_fp fp
    @filtered_presenter = fp
    @decorator = fp.decorator
    @entity = fp.entity
    case fp.content_mode
      when :container  # Handle the overall layout
        render 'filtered_presenter/presentation'
      when :entity # Summarize the focused entity
        # Do a conventional #show, i.e., render the stream's entity's show template
        render :show  # The #show template will expect @decorator to be defined
      when :results # The frame for the items. This may be recursive on other frameworks
        # Do a conventional #index, i.e. render the stream container
        render template: 'filtered_presenter/results'
      when :modal
        # Render the stream's entity in a modal dialog
        render :show, locals: { decorator: @decorator, viewparams: fp.viewparams }
      when :items # Stream items into the stream's container
        renderings = [ { deletions: [".stream-tail.#{fp.stream_id}"] } ]
        items = []
        NestedBenchmark.measure 'Fetch items for display: ' do
          while item = fp.next_item do
            items << item
          end
        end
        items.each do |item|
          renderings << {
              elmt: with_format("html") {
                admin_sensitive = [:table, :card].include? fp.item_mode
                # cache item do
                NestedBenchmark.measure "Render item ##{item.id}: " do
                  cache [item, fp.item_mode, admin_sensitive && response_service.admin_view?] do
                    puts "Cache miss rendering element #{item}"
                    view_context.render_item item, fp.item_mode
                  end
                end
              }
          }
        end
        renderings << { elmt: with_format("html") { render_to_string partial: "filtered_presenter/present/#{fp.tail_partial}", locals: { decorator: @decorator, viewparams: fp.viewparams } } } if fp.next_path
        render json: renderings
=begin
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        # retrieve_seeker
        begin
          sse = Reloader::SSE.new response.stream
          renderings.each do |rendering|
              sse.write :stream_item, rendering
          end
        rescue IOError
          logger.info "Stream closed"
        ensure
          # In closing, replace the trigger to make it active again--or not
          sse.close
        end
        fp.suspend
=end
        true
    end
  end

  def permission_denied
    action = case params[:action]
               when "index"
                 "see the list of all"
               when "show"
                 "examine"
               when "new"
                 params[:controller] == "recipes" ? "cookmark" : "create new"
               else
                 params[:action]
             end
    flash[:alert] = "Sorry, but as a #{User.current_or_guest.role}, you're not allowed to #{action} #{params[:controller]}."
    respond_to do |format|
      format.html { redirect_to(:back) rescue redirect_to('/') }
      format.json {
        notif = view_context.flash_notify
        render json: notif
      }
      format.xml { head :unauthorized }
      format.js { head :unauthorized }
    end
  end

  def no_action_error
    redirect_to home_path, :notice => "Sorry, action not found"
  end

  def timeout_error
    redirect_to authentications_path, :notice => "Sorry, access to that page took too long."
  end

  def rescue_action_in_public
    x=2
  end

  # alias_method :rescue_action_locally, :rescue_action_in_public

  def setup_response_service
    @response_service ||= ResponseServices.new params, session, request
    @response_service.controller_instance = self
    # This is a unique identifier for a computer, stored as a cookie to persist across sessions
    @response_service.uuid = cookies[:rp_uuid] || (cookies[:rp_uuid] = session.id)
    @response_service
  end

  # This object directs conditional view code according to target device and context
  def response_service
    @response_service || setup_response_service
  end

  def orphantagid(tagid)
    "orphantag_"+tagid.to_s
  end

  include ControllerAuthentication

  # Enable a modal dialog to run by embedding its URL in the URL of a page, then redirecting to it
  def redirect_to_modal dialog, page=nil
    # Transfer the contents of the flash to the trigger
    options = {mode: :modal}
    flash.each { |type, message| options["flash[#{type}]"] = message } if defined?(flash)
    page = page.if_present || (current_user ? collection_user_path(current_user) : '/home')
    redirect_to view_context.page_with_trigger(page, assert_query(dialog, options))
  end

  # before_action on controller that needs login to do anything
  def  login_required options={}
    unless current_user # User.current has not yet been set at this point
      summary = action_summary params[:controller], params[:action]
      alert = "You need to be logged in to an account on RecipePower to #{summary}."
      unless session.id
        reset_session
        response_service.uuid = session.id
      end
      if session.id || true
        request_options = { path: request.fullpath,
            format: (response_service.mode == :injector ? :json : request.format.symbol)
        }.merge(options.slice :path, :format)
        defer_request request_options
        redirect_to(if (response_service.format == :json)
                      flash[:alert] = alert
                      defer_invitation_path(response_service.redirect_params(response_service.params_hash.slice(:sourcehome)).merge notif: 'signup' )
                    elsif response_service.mode == :injector
                      new_user_session_url(response_service.redirect_params response_service.params_hash.slice(:sourcehome))
                    elsif options[:login_direct]
                      new_user_registration_url notif: 'signin', header: 'Sorry, members only', flash: {alert: alert}
                    else
                      # Redirect to the home page with a login popup trigger
                      home_path
                    end
        )
      else
        report_cookie_string
        report_session "Unauthorized Login:"
        raise alert
        render :file => "public/401.html", :layout => false, :status => :unauthorized
      end
    end
  end

  def build_resource(*args)
    super
    if omniauth = session[:omniauth]
      response_service.user.apply_omniauth(omniauth)
      response_service.user.authentications.build(omniauth.slice('provider', 'uid'))
      response_service.user.valid?
    end
  end

#  protect_from_forgery

  def stored_location_for(resource_or_scope)
    # If user is logging in to complete some process, we return
    # the path to completing the capture/tagging process
    if response_service.injector?
      deferred_request
    else
      if specs = specs_matching(:format => :html)
        deferred_request specs
      elsif current_user.sign_in_count < 2
        flash = {success: "Welcome to RecipePower, #{current_user.handle}. This is your collection page, which you can always reach from the Collections menu above."}
        deferred_request path: collection_user_path(current_user, flash: flash), :format => :html
      else
        deferred_request path: collection_user_path(current_user), :format => :html
      end
    end || super
  end

  # When a user signs up or accepts an invitation, they'll see these dialogs, in reverse order
  def defer_welcome_dialogs
    dialog = specs_matching(path: '/collect', format: :html) ? view_context.new_page_ref_path : '/cookmark'
    defer_request path: dialog, :mode => :modal, :format => :json
    # defer_request path: "/popup/need_to_know?context=signup", :mode => :modal, :format => :json
    # defer_request path: "/popup/starting_step3?context=signup", :mode => :modal, :format => :json
    # defer_request path: "/popup/starting_step2?context=signup", :mode => :modal, :format => :json
  end

  protected

  include ControllerDeference

  def render_optional_error_file(status_code)
    logger.info 'Logger sez: Error 500'
    render :template => 'errors/500', :status => 500, :layout => 'application'
  end

  private

  # The capture action should be embeddable in the iframe
  def allow_iframe
    # response.headers.except! 'X-Frame-Options'
    response.header['X-Frame-Options'] = 'ALLOWALL'
  end
end
