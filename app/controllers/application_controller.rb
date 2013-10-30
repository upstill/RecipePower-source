require './lib/controller_authentication.rb'
require './lib/seeker.rb'

class ApplicationController < ActionController::Base
  # layout :rs_layout # Declare in any controller to let response_service pick the layout
  protect_from_forgery with: :exception
  
  before_filter :check_flash
  before_filter :report_cookie_string
  before_filter :detect_notification_token
  before_filter :setup_response_service
    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    rescue_from AbstractController::ActionNotFound, :with => :no_action_error
    
    helper_method :response_service
    helper_method :orphantagid
    helper_method :stored_location_for
    helper_method :deferred_capture
    helper_method :deferred_collect
    helper_method :deferred_notification
    include ApplicationHelper
  
  # Use the layout stipulated by the response_service
  def rs_layout
    response_service.layout
  end
    
  # Get a presenter for the object fron within a controller
  def present(object, klass = nil)
    klass ||= "#{object.class}Presenter".constantize
    klass.new(object, view_context)
  end  
  
  def detect_notification_token
    session[:notification_token] = params[:notification_token] if params[:notification_token]
  end
  
  def check_flash
    logger.debug "FLASH messages extant for "+params[:controller]+"#"+params[:action]+"(check_flash):"
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
  
  # Get the seeker from the session store (mainly used for streaming)
  def retrieve_seeker
    if klass = session[:seeker_class]
      setup_seeker klass
    end
  end
  
  def setup_seeker(klass, options=nil, params=nil)
    @user ||= current_user_or_guest
    @browser ||= @user.browser
    @seeker = "#{klass}Seeker".constantize.new @user, @browser, session[:seeker], params # Default; other controllers may set up different seekers
    @seeker.tagstxt = "" if options && options[:clear_tags]
    session[:seeker] = @seeker.store
    session[:seeker_class] = klass
    @seeker
  end
  
  # All controllers displaying the collection need to have it setup 
  def setup_collection klass="Content", options={}
    if popup = params[:popup]
      session[:flash_popup] = popup
      redirect_to collection_path
    else
      @user = current_user_or_guest
      @browser = @user.browser
      default_options = {}
      default_options[:clear_tags] = (params[:controller] != "collection") && (params[:controller] != "stream")
      setup_seeker klass, default_options.merge(options), params
      if params[:selected]
        @browser.select_by_id(params[:selected])
        @seeker.cur_page = 1
      end
      if (params[:controller] == "pages")
        # The search box in generic pages redirects collections, either "The Big List" for guests or
        # the user's whole collection 
        @browser.select_by_id(@user.guest? ? "RcpBrowserElementAllRecipes" : "RcpBrowserCompositeUser")
        @user.save
        format = "html"
        query_path = collection_path
      else
        format = "json"
        query_path = @seeker.query_path
      end
      content_for :seeker_entry, 
                  render_to_string(
                    :template => "shared/seeker_entry", 
                    :layout => false,
                    :locals => { format: format, query_path: query_path }
                  ).html_safe
    end
  end
  
  # This is one-stop-shopping for a controller using the query to filter a list
  # See tags_controller for an example
  # Options: selector: CSS selector for the outermost container of the rendered index template
  def seeker_result(klass, options={})
    respond_to do |format|
      format.html { 
        setup_collection klass, options
        render :index 
      }
      format.json do 
    	  setup_seeker(klass, options.slice(:clear_tags, :scope), params)
        replacement = with_format("html") { render_to_string 'index', :layout=>false }
        selector = options[:selector] || "div.#{klass.to_s.downcase}_list"
        render json: { replacements: [
                            view_context.flash_notifications_replacement,
                            [ selector, replacement ]
                        ] 
                      }
      end
    end
  end
  
  # Generalized response for dialog for a particular area
  def smartrender(renderopts={})
    action = renderopts[:action] || params[:action]
    flash.now[:notice] = params[:notice] unless flash[:notice] # ...should a flash message come in via params
    # @_area = params[:_area]
    # @_layout = params[:_layout]
    # @_partial = !params[:_partial].blank?
    # Apply the default render params, honoring those passed in
    renderopts = response_service.render_params renderopts
    respond_to do |format|
      format.html {
        # @_area ||= "page"  
        if response_service.page? # @_area == "page" # Not partial at all => whole page
          if renderopts[:redirect]
            redirect_to renderopts[:redirect]
          else
            render action, renderopts
          end
        else
          # renderopts[:_layout] = (@_layout || false)
          render action, renderopts # May have special iframe layout
        end
       }
      format.json { 
        hresult = with_format("html") do
          # Blithely assuming that we want a modal-dialog element if we're getting JSON
          renderopts[:layout] = (@layout || false)
          render_to_string action, renderopts # May have special iframe layout
        end
        renderopts[:json] = { code: hresult, area: response_service.area_class, how: "bootstrap" }
        render renderopts
      }
      format.js {
        # XXX??? Must have set @partial in preparation
        debugger
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
    @response_service ||= ResponseServices.new params, session
    # Mobile is sticky: it stays on for the session once the "mobile" area parameter appears
    @response_service.is_mobile if (params[:area] == "mobile")
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
  protect_from_forgery
  
  def stored_location_for(resource_or_scope)
    # If user is logging in to complete some process, we return 
    # the path to completing the capture/tagging process
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    redir = 
    if scope && (scope==:user)
      if response_service.injector? # params[:_area] == "at_top" # Signing in from remote site => respond directly
        logger.debug "stored_location_for: Getting stored location..."
        raise "XXXX stored_location_for: Can't get deferred capture" unless dc = deferred_capture(true)
        capture_recipes_url dc
      else
        if (nt = session[:notification_token]) && 
          (notification = Notification.where(notification_token: nt).first) && 
          (notification.target == current_user)
            session.delete(:notification_token)
            notification.accept
        end
        if col = deferred_collect(true)
          Recipe.ensure current_user.id, col
        end
        # Signing in from RecipePower => load collection, let deferred
        # capture call be made on client side with a trigger
        collection_path redirect: true
      end
    end
    redir || super
  end
  
  # This is an override of the Devise method to determine where to go after login.
  # If there was a redirect to the login page, we go back to the source of the redirect.
  # Otherwise, new users go to the welcome page and logged-in-before users to the queries page.
  def after_sign_in_path_for(resource_or_scope)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    stored_location_for(resource_or_scope) || 
    (scope && (scope==:user) && collection_path(redirect: true)) || 
    super
  end
  
  def defer_invitation
    if params[:invitation_token]
      session[:invitation_token] = params[:invitation_token]
    else
      session.delete :invitation_token
    end
    deferred_invitation
  end
  
  # Validate and return the extant invitation token
  def deferred_invitation
    if token = session[:invitation_token] 
      unless User.find_by_invitation_token(token, true)
        token = nil
        session.delete :invitation_token 
      end
    end
    token
  end
  
  def defer_notification
    if params[:notification_token]
      session[:notification_token] = params[:notification_token]
    else
      session.delete :notification_token
    end
    deferred_notification
  end
  
  def deferred_notification
    if token = session[:notification_token] 
      unless Notification.exists? :notification_token => token
        token = nil
        session.delete :notification_token 
      end
    end
    token
  end
  
  # def after_sign_in_path_for(resource_or_scope)
    # recall_capture || collection_path
    # stripped_capture
    # redirect_url = recall_capture || collection_path
    # stored_location_for(resource_or_scope) || signed_in_root_path(resource_or_scope)
  # end
  
  def defer_collect(rid, uid)
    session[:collect_data] = { id: rid, uid: uid }
  end
  
  def deferred_collect(delete=false)
    if data = session[:collect_data]
      session.delete(:collect_data) if delete
    end
    data
  end
  
  # In the event that a recipe capture is deferred by login, this stores the requisite information
  # in the session for retrieval after login
  def defer_capture data
    if data
      session[:capture_data] = data.clone
    else
      session.delete :capture_data
    end
  end
  
  def deferred_capture forget=false
    if cd = session[:capture_data]
      logger.debug "deferred_capture: Deferred capture '#{cd}' is #{forget ? '' : 'not '}to be forgotten"
      session.delete(:capture_data) if forget
      cd
    end
  end

  def stripped_capture forget=false
    # Edge case: we may get here in the course of authorizing collecting a recipe, in 
    # which case we forget about handling it in the embedded iframe: remove the "area=at_top" 
    # and "layout=injector" query parameters
    if capture_data = deferred_capture(forget)
      capture_data.delete :area
      capture_data.delete :layout
      capture_data.delete :context
      capture_data
    end
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
