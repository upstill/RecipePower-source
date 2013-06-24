require './lib/controller_authentication.rb'
require './lib/seeker.rb'

class ApplicationController < ActionController::Base
  before_filter :setup_collection
  before_filter :check_flash
    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    rescue_from AbstractController::ActionNotFound, :with => :no_action_error
    
    helper_method :orphantagid
    
  # Get a presenter for the object fron within a controller
  def present(object, klass = nil)
    klass ||= "#{object.class}Presenter".constantize
    klass.new(object, view_context)
  end  
  
  def check_flash
    logger.debug "FLASH messages extant for "+params[:controller]+"#"+params[:action]+"(check_flash):"
    puts "    notice: "+flash[:notice] if flash[:notice]
    puts "    error: "+flash[:error] if flash[:error]
    session[:on_tour] = true if params[:on_tour]
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
  
  # This is an override of the Devise method to determine where to go after login.
  # If there was a redirect to the login page, we go back to the source of the redirect.
  # Otherwise, new users go to the welcome page and logged-in-before users to the queries page.
  def after_sign_in_path_for(resource)
    redirect = stored_location_for(resource)
    logger.debug "AFTER SIGNIN, STORED LOCATION IS "+(redirect||"empty")
    redirect ||
        if resource.is_a?(User)
          # flash[:notice] = "Congratulations, you're signed up!"
          # resource.sign_in_count < 2 ? welcome_path : collection_path
          collection_path
        else
          super(resource)
        end
  end

  # redirect somewhere that will eventually return back to here
  def redirect_away(url, options = {})
    logger.debug "REDIRECTING AWAY FROM "+request.url+" TO "+url
    session[:original_uri] = request.url # url.sub /\w*:\/\/[^\/]*/, ''
    redirect_to url, options
  end
  
  # save the given url in the expectation of coming back to it
  def push_page(url)
      logger.debug "PUSHING PAGE TO "+url
      session[:original_uri] = url
  end

  # returns the person to either the original url from a redirect_away or to a provided, default url
  def redirect_back(options = {})
    uri = session[:original_uri] || collection_path
    logger.debug "REDIRECTING BACK TO "+uri
    session[:original_uri] = nil
    redirect_to uri, options
  end
  
  protected
    def render_optional_error_file(status_code)
      logger.info "Logger sez: Error 500"
      render :template => "errors/500", :status => 500, :layout => 'application'
    end
end
