require './lib/controller_authentication.rb'

class ApplicationController < ActionController::Base
    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    rescue_from AbstractController::ActionNotFound, :with => :no_action_error
    
    helper_method :orphantagid
  
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
        debugger
        redirect_to home_path, :notice => "Sorry, action not found"
    end
    
    def timeout_error
        debugger
        redirect_to authentications_path, :notice => "Sorry, access to that page took too long."
    end
    
    def rescue_action_in_public
        debugger
        x=2
    end
    # alias_method :rescue_action_locally, :rescue_action_in_public    
    
    def orphantagid(tagid)
        "orphantag_"+tagid.to_s
    end
      
  include ControllerAuthentication
  protect_from_forgery
  
  def after_sign_in_path_for(resource)
    loc = stored_location_for(resource)
    debugger
    loc ||
      if resource.is_a?(User)
        # flash[:notice] = "Congratulations, you're signed up!"
        if resource.sign_in_count < 2
          return welcome_path
        else
          return rcpqueries_path
        end
      else
        super(resource)
      end
  end

  # redirect somewhere that will eventually return back to here
  def redirect_away(url, options = {})
    session[:original_uri] = request.url # url.sub /\w*:\/\/[^\/]*/, ''
    redirect_to url, options
  end
  
  # save the given url in the expectation of coming back to it
  def push_page(url)
      session[:original_uri] = url
  end

  # returns the person to either the original url from a redirect_away or to a provided, default url
  def redirect_back(options = {})
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
