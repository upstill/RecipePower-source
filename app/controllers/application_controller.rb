require './lib/controller_authentication.rb'
# require './lib/seeker.rb'
require './lib/querytags.rb'
require 'rp_event'
require 'reloader/sse'
require 'results_cache.rb'

class ApplicationController < ActionController::Base
  include Querytags # Grab the query tags from params for filtering a list
  # include ActionController::Live   # For streaming
  # layout :rs_layout # Declare in any controller to let response_service pick the layout
  protect_from_forgery with: :exception
  
  before_filter :check_flash
  before_filter :report_cookie_string
  after_filter :report_session
  # before_filter :detect_notification_token
  before_filter :setup_response_service
  before_filter :log_serve

    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    rescue_from AbstractController::ActionNotFound, :with => :no_action_error
    
    helper_method :response_service
    helper_method :orphantagid
    helper_method :stored_location_for
    helper_method :collection_path

    include ApplicationHelper

  # Incorporate changes to temporary fields into the persisted model
  def accept_params entity = nil
    modelname = params[:controller].sub( /_controller$/, '').singularize
    modelsym = modelname.to_sym
    objclass = modelname.camelize.constantize
    if params[:id]
      entity ||= objclass.find params[:id]
      entity.update_attributes params[modelsym] if params[modelsym]
    else
      entity ||= objclass.new (params[modelsym] || {})
      entity.save
    end
    entity.accept_params
    instance_variable_set :"@#{modelname}", entity
    @decorator = entity.decorate unless entity.errors.any?
    entity
  end

  # Set up a model for editing, whether new or fetched
  # Asserting an entity assumes that it is up to date
  def prep_params entity = nil
    modelname = params[:controller].sub( /_controller$/, '').singularize
    modelsym = modelname.to_sym
    objclass = modelname.camelize.constantize
    unless entity
      entity = params[:id] ? objclass.find(params[:id]) : objclass.new
      entity.update_attributes(params[modelsym]) if params[modelsym]
    end
    entity.prep_params @user.id
    instance_variable_set :"@#{modelname}", entity
    @decorator = entity.decorate unless entity.errors.any?
    entity
  end

  # This replaces the old collections path, providing a path to either the current user's collection or home
  def collection_path
    current_user ? user_collection_path(current_user) : home_path
  end

  # Track the session, saving session events when the session goes stale
  def log_serve
    logger.info %Q{RPEVENT\tServe\t#{current_user.id if current_user}\t#{params[:controller]}\t#{params[:action]}\t#{params[:id]}}
    RpEvent.fire_trigger(params[:rpevent]) if params[:rpevent]
    return unless current_user
    if session[:start_time] && session[:last_time]
      time_now = Time.now
      elapsed_time = time_now - session[:last_time]
      if (elapsed_time < 10.minutes)
        session[:last_time] = time_now
        session[:serve_count] += 1
        return
      elsif last_serve = RpEvent.last(:serve, current_user)
        # Close out and update the previous session to record serve count and last time
        last_serve.data = { serve_count: session[:serve_count] }
        last_serve.updated_at = session[:last_time]
        last_serve.save
      end
    end
    last_serve = RpEvent.post current_user, :serve, nil, nil, :serve_count => 1
    session[:serve_count] = 1
    session[:start_time] = session[:last_time] = last_serve.created_at
  end

  # Use the layout stipulated by the response_service
  def rs_layout
    response_service.layout
  end
    
  # Get a presenter for the object fron within a controller
  def present(object, rc_class = nil)
    rc_class ||= "#{object.class}Presenter".constantize
    rc_class.new(object, view_context)
  end  

  def check_flash
    logger.debug "FLASH messages extant for #{params[:controller]}##{params[:action]} (check_flash):"
    logger.debug "    notice: "+flash[:notice] if flash[:notice]
    logger.debug "    error: "+flash[:error] if flash[:error]
		session[:on_tour] = true if params[:on_tour]
		session[:on_tour] = false if current_user
  end
  
  def report_cookie_string
    logger.info "COOKIE_STRING:"
    if cs = request.env["rack.request.cookie_string"]
      cs.split('; ').each { |str| logger.info "\t"+str}
    end
  end

  def report_session
    logger.info "COOKIES after controller:"
    response.cookies.each { |k, v| logger.info "#{k}: #{v}" }
    x=2
  end

  # Take a stream presenter and drop items into a stream, if possible and called for.
  # Otherwise, defer to normal rendering
  def do_stream rc_class
    @sp = StreamPresenter.new session.id, request.fullpath, rc_class, current_user_or_guest_id, querytags, params
    if block_given?
      yield @sp
    end
    if @sp.stream?  # We're here to spew items into the stream
      # When the stream is request is for the first items, replace the results
      if @sp.preface?
        # Generally, start by restarting the results element and replacing the found count
        header_item = with_format("html") {
          { replacements: [
              view_context.stream_element_replacement(:results),
              view_context.stream_element_replacement(:count, final_count: true)
          ] }
        }
      else
        header_item = { deletions: [ '.stream-tail' ] }
      end
      response.headers["Content-Type"] = "text/event-stream"
      # retrieve_seeker
      begin
        sse = Reloader::SSE.new response.stream
        sse.write :stream_item, header_item

        while item = @sp.next_item do
          sse.write :stream_item, with_format("html") { { elmt: view_context.render_stream_item(item) } }
        end
        if @sp.next_path
          sse.write :stream_item, with_format("html") { { elmt: view_context.render_stream_tail } }
        end
      rescue IOError
        logger.info "Stream closed"
      ensure
        # In closing, replace the trigger to make it active again--or not
        sse.close # replacements: [ with_format("html") { view_context.stream_element_replacement(:tail) } ]
      end
      @sp.suspend
      true
    end
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
  def smartrender(renderopts={})
    response_service.action = renderopts[:action] || params[:action]
    url = renderopts[:url] || request.original_url
    # flash.now[:notice] = params[:notice] unless flash[:notice] # ...should a flash message come in via params
    # @_area = params[:_area]
    # @_layout = params[:_layout]
    # @_partial = !params[:_partial].blank?
    # Apply the default render params, honoring those passed in
    renderopts = response_service.render_params renderopts
    respond_to do |format|
      format.html do
        if response_service.page? && renderopts[:redirect_to]
          redirect_to renderopts[:redirect_to]
        elsif response_service.dialog?
          # Run the request as a dialog within the collection page
          redirect_to_modal url
        else
          render response_service.action, renderopts
        end
      end
      format.json {
        if response_service.partial?
          renderopts[:layout] = false
          if @sp
            # If operating with a stream, package the content into a stream-body element, with stream trigger
            renderopts[:action] = response_service.action
            begin
              replname = @sp.has_query? ? "shared/stream_results_replacement" : "shared/pagelet_body_replacement"
              render template: replname, layout: false
            rescue Exception => e
              x=2
            end
          else
            render renderopts
          end
        else
          # Blithely assuming that we want a modal-dialog element if we're getting JSON and not a partial
          response_service.is_dialog
          dialog = render_to_string renderopts.merge(action: response_service.action, layout: (@layout || false), formats: ["html"])
          render json: {code: dialog, how: "bootstrap"}.to_json, layout: false, :content_type => 'application/json'
        end
      }
      format.js {
        # XXX??? Must have set @partial in preparation
        render renderopts.merge( action: "capture" )
      }
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
    notice = "Sorry, but as a #{current_user_or_guest.role}, you're not allowed to #{action} #{params[:controller]}."
    respond_to do |format|
      format.html { redirect_to(:back, notice: notice) rescue redirect_to('/', notice: notice) }
      format.xml  { head :unauthorized }
      format.js   { head :unauthorized }
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
    @user = current_user_or_guest
    @response_service ||= ResponseServices.new params, session, request
    # Mobile is sticky: it stays on for the session once the "mobile" target parameter appears
    @response_service.is_mobile if (params[:target] == "mobile")
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

  def page_with_trigger dialog, page=nil
    triggerparam = assert_query(dialog, modal: true)
    pt = assert_query (page || collection_path), trigger: %Q{"#{triggerparam}"}
    logger.debug "page_with_trigger reporting #{pt} on default page '#{page}' and collection_path '#{collection_path}'."
    pt
  end

  # Enable a modal dialog to run by embedding its URL in the URL of a page, then redirecting to it
  def redirect_to_modal dialog, page=nil
    redirect_to page_with_trigger(dialog, page )
  end

  # before_filter on controller that needs login to do anything
  def login_required alert = "Let's get you logged in so we can do this properly.", elements={}
    unless logged_in?
      elements = response_service.defer_request elements
      flash[:alert] = alert if alert
      if elements[:format] == :json
        redirect_to new_authentication_url(recipe_service.params params.slice(:sourcehome) )
      else
        redirect_to new_user_session_url( response_service.redirect_params params.slice(:sourcehome) )
      end
    end
  end

  # This overrides the method for returning to a request after logging in. Formerly, session[:return_to]
  # handled this recovery
  def redirect_to_target_or_default(default, *args)
    redirect_to( response_service.deferred_request || default, *args)
  end

  def build_resource(*args)
    super
    if omniauth = session[:omniauth]
      @user.apply_omniauth(omniauth)
      @user.authentications.build(omniauth.slice('provider','uid'))
      @user.valid?
    end
  end

  protect_from_forgery

  def stored_location_for(resource_or_scope)
    # If user is logging in to complete some process, we return
    # the path to completing the capture/tagging process
    response_service.deferred_request || super
  end

  # This is an override of the Devise method to determine where to go after login.
  # If there was a re-direct to the login page, we go back to the source of the re-direct.
  # Otherwise, new users go to the welcome page and logged-in-before users to the queries page.
  def after_sign_in_path_for(resource_or_scope, popup = nil)
    # Process any pending notifications
    view_context.issue_notifications current_user
    path = stored_location_for(resource_or_scope) || collection_path
    path = page_with_trigger(popup, path) if popup # Trigger the intro popup
    # If on the site, login triggers a refresh of the collection
    response_service.url_for_redirect(path, :format => :html)
  end

  protected
    def render_optional_error_file(status_code)
      logger.info "Logger sez: Error 500"
      render :template => "errors/500", :status => 500, :layout => 'application'
    end

  private

  # The capture action should be embeddable in the iframe
  def allow_iframe
    # response.headers.except! 'X-Frame-Options'
  	response.header['X-Frame-Options'] = "ALLOWALL"
  end
end
