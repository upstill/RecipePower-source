require './lib/controller_authentication.rb'
require './lib/seeker.rb'
require 'rp_event'

class ApplicationController < ActionController::Base
  # layout :rs_layout # Declare in any controller to let response_service pick the layout
  protect_from_forgery with: :exception
  
  before_filter :check_flash
  before_filter :report_cookie_string
  # after_filter :report_session
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
    helper_method :deferred_capture
    helper_method :deferred_collect
    # helper_method :deferred_notification
    include ApplicationHelper

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
    last_serve = RpEvent.post :serve, current_user, nil, nil, :serve_count => 1
    session[:serve_count] = 1
    session[:start_time] = session[:last_time] = last_serve.created_at
  end

  # Use the layout stipulated by the response_service
  def rs_layout
    response_service.layout
  end
    
  # Get a presenter for the object fron within a controller
  def present(object, klass = nil)
    klass ||= "#{object.class}Presenter".constantize
    klass.new(object, view_context)
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
      cs.split('; ').each { |str| 
        logger.info "\t"+str
        if m = str.match( /_rp_session=(.*)$/ )
          sess = Rack::Session::Cookie::Base64::Marshal.new.decode(m[1])
          logger.info "\t\t"+sess.pretty_inspect
        end
      }
    end
    logger.info "SESSION STORE:"
    if cook = env["action_dispatch.request.unsigned_session_cookie"]
      logger.info "\t\t"+cook.pretty_inspect
    else
      logger.info "\t\t= NIL"
    end
  end

  def report_session
    logger.info "COOKIES after controller:"
    response.cookies.each { |k, v| logger.info "#{k}: #{v}" }
    x=2
  end
  
  # Get the seeker from the session store (mainly used for streaming)
  def retrieve_seeker
    if klass = session[:seeker_class]
      setup_seeker klass
    end
  end

  def handle_unverified_request
    logger.debug "Unverified request resetting session"
    super
  end
  
  def setup_seeker(klass, options=nil, params=nil)
    @user ||= current_user_or_guest
    params[:cur_page] = "1" if params && params[:selected]
    @browser = @user.browser params
    @user.save
    # Go back to page 1 when a new browser element is selected
    logger.debug "Fetching #{klass}Seeker with session[:seeker]="+session[:seeker].to_s
    @seeker = "#{klass}Seeker".constantize.new @user, @browser, session[:seeker], params # Default; other controllers may set up different seekers
    @seeker.tagstxt = "" if options && options[:clear_tags]
    session[:seeker] = @seeker.store
    session[:seeker_class] = klass
    logger.debug "@seeker returning #{@seeker ? 'not ' : ''}nil."
    @seeker
  end
  
  # All controllers displaying the collection need to have it setup 
  def setup_collection klass="Content", options={}
      @user ||= current_user_or_guest
      @browser = @user.browser params
      default_options = {}
      default_options[:clear_tags] = (params[:controller] != "collection") && (params[:controller] != "stream")
      setup_seeker klass, default_options.merge(options), params
      if (params[:controller] == "pages")
        # The search box in generic pages redirects collections, either "The Big List" for guests or
        # the user's whole collection 
        @browser.select_by_id(@user.guest? ? "RcpBrowserElementAllRecipes" : "RcpBrowserCompositeUser")
        @user.save
        @query_format = "html"
        @query_path = collection_path
      else
        @query_format = "json"
        @query_path = @seeker.query_path
      end
    # end
  end
  
  # This is one-stop-shopping for a controller using the query to filter a list
  # See tags_controller for an example
  # Options: selector: CSS selector for the outermost container of the rendered index template
  def seeker_result(klass, frame_selector, options={})
    def jsondata(klass, frame_selector, options)
      # In a json response we just re-render the collection list for replacement
      # If we need to replace the page, we send back a link to do it with
      if params[:redirect]
        { redirect: assert_popup(nil, request.original_url) }
      else
        begin
          setup_seeker(klass, options.slice(:clear_tags, :scope), params)
        rescue Exception => e
          # Response to a setup error is to reload the collections page
          flash[:error] = e.to_s
          return { redirect: "/collection" }
        end

        # flash.now[:guide] = @seeker.guide
        # If this is the first page, we replace the list altogether, wiring the list
        # to stream results. If it's a subsequent page, we just set up a stream to serve that page.
        if (@seeker.cur_page == 1)
          replacements = [
              view_context.flash_notifications_replacement,
              [ frame_selector, with_format("html") { render_to_string 'index', :layout=>false } ]
          ]
          unless @rp_old
            replacements << [ '.collection-navtabs', with_format("html") { render_to_string partial: "collection/navtabs", :layout=>false } ]
            replacements << [ '.collection-header', with_format("html") { render_to_string partial: "collection/header", :layout=>false } ]
          end
          { replacements: replacements }
        else
          {  streams: [ ['#seeker_results', {kind: @seeker.class.to_s, append: @seeker.cur_page.to_i>1}] ] }
        end
      end
    end
    respond_to do |format|
      format.html {
        params[:cur_page] = 1
        setup_collection klass, options
        # flash.now[:guide] = @seeker.guide
        render :index
      }
      format.js do
        @jsondata = jsondata(klass, frame_selector, options)
        render template: "shared/get_content"
      end
      format.json { render json: jsondata(klass, frame_selector, options) }
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
        # Blithely assuming that we want a modal-dialog element if we're getting JSON
        response_service.is_dialog
        renderopts[:layout] = (@layout || false)
        hresult = with_format("html") do
          render_to_string response_service.action, renderopts # May have special iframe layout
        end
        # renderopts[:json] = { code: hresult, area: response_service.format_class, how: "bootstrap" }
        renderopts[:json] = { code: hresult, how: "bootstrap" }
        render renderopts
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

  # Enable a modal dialog to run by embedding its URL in the URL of a page, then redirecting to it
  def redirect_to_modal dialog, page=nil
    redirect_to hash_to_modal(dialog, page)
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
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    if scope && (scope==:user)
      # If on the site, login triggers a refresh of the collection
      response_service.deferred_request || response_service.url_for_redirect(collection_path, :format => :html)
    end || super
  end

  # This is an override of the Devise method to determine where to go after login.
  # If there was a re-direct to the login page, we go back to the source of the re-direct.
  # Otherwise, new users go to the welcome page and logged-in-before users to the queries page.
  def after_sign_in_path_for(resource_or_scope)
    # Process any pending notifications
    notices = current_user.notifications_received.where(accepted: false).collect { |notification| notification.accept }.join('<br>'.html_safe)
    flash[:success] = notices unless notices.blank?
    stored_location_for(resource_or_scope) || super
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
