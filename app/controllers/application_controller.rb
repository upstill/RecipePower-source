require './lib/controller_authentication.rb'
require './lib/seeker.rb'

class ApplicationController < ActionController::Base
  before_filter :setup_collection
  before_filter :check_flash
  before_filter :detect_notification_token
    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    rescue_from AbstractController::ActionNotFound, :with => :no_action_error
    
    helper_method :orphantagid
    helper_method :stored_location_for
    helper_method :deferred_capture
    helper_method :deferred_collect
    helper_method :deferred_notification
    include ApplicationHelper
    
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
    puts "    notice: "+flash[:notice] if flash[:notice]
    puts "    error: "+flash[:error] if flash[:error]
		session[:on_tour] = true if params[:on_tour]
		session[:on_tour] = false if current_user
  end
  
  def init_seeker(klass, clear_tags=false, scope=nil)
    @user = current_user_or_guest
    @seeker = "#{klass}Seeker".constantize.new (scope || klass.scoped), session[:seeker], params # Default; other controllers may set up different seekers
    @seeker.tagstxt = "" if clear_tags
    session[:seeker] = @seeker.store
  end
  
  # All controllers displaying the collection need to have it set up. This should be called after prefiltering (i.e., init_seeker) as it supplants
  # the default seeker.
  def setup_collection
    @user = current_user_or_guest
    @browser = @user.browser
    @seeker = ContentSeeker.new @browser, session[:seeker] # Default; other controllers may set up different seekers
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
      if params[:area] == "at_top" # Signing in from remote site => respond directly
        capture_recipes_url deferred_capture(true)
      else
        if (nt = session[:notification_token]) && 
          (notification = Notification.where(notification_token: nt).first) && 
          (notification.target == current_user)
            session.delete(:notification_token)
            notification.accept
        end
        # Signing in from RecipePower => load collection, let deferred
        # capture call be made on client side with a trigger
        collection_path href: true
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
    (scope && (scope==:user) && collection_path(href: true)) || 
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
      unless User.exists? :invitation_token => token
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
      capture_data
    end
  end
            
  protected
    def render_optional_error_file(status_code)
      logger.info "Logger sez: Error 500"
      render :template => "errors/500", :status => 500, :layout => 'application'
    end
end
