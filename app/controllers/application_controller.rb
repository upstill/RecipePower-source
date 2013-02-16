require './lib/controller_authentication.rb'

class ApplicationController < ActionController::Base
  before_filter :setup_collection
    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    rescue_from AbstractController::ActionNotFound, :with => :no_action_error
    
    helper_method :orphantagid
  
  # All controllers displaying the collection need to have it setup 
  def setup_collection
    @user_id = current_user_or_guest_id 
    @user = User.find(@user_id)
    @collection = @user.browser
    # Initialize any entities for which we're building a New dialog on the page
    @feed = Feed.new
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
          resource.sign_in_count < 2 ? welcome_path : rcpqueries_path
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
    logger.debug "REDIRECTING BACK TO "+(session[:original_uri] || "rcpqueries_path")
    uri = session[:original_uri] || rcpqueries_path
    session[:original_uri] = nil
    redirect_to uri, options
  end
  
  protected
    def render_optional_error_file(status_code)
      logger.info "Logger sez: Error 500"
      render :template => "errors/500", :status => 500, :layout => 'application'
    end
end
