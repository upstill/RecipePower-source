require './lib/controller_authentication.rb'

class ApplicationController < ActionController::Base
    helper :all
    rescue_from Timeout::Error, :with => :timeout_error # self defined exception
    rescue_from OAuth::Unauthorized, :with => :timeout_error # self defined exception
    
    helper_method :orphantagid
    
    def timeout_error
        debugger
        redirect_to authentications_path, :notice => "Sorry, access to that page took too long."
    end
    
    def orphantagid(tagid)
        "orphantag_"+tagid.to_s
    end
      
  include ControllerAuthentication
  protect_from_forgery

=begin
# Gateway to (most) controllers: check that there's a current user
# and don't do anything until there is one. If login isn't required,
# set the session user id to guest
def need_login(login_required, super_required = false)
    if login_required
        if super_required
            # XXX Currently ad-hoc-ly treating Max, Aaron and Steve as super
            if session[:user_id].nil? || session[:user_id] > 5 || (session[:user_id] == User.guest_id)
                @Title = "Login"
                redirect_away login_url, :notice=>"You must be logged in as super to go there."
                return true
            else
                return false
            end
        elsif !session[:user_id] || session[:user_id] == User.guest_id
            @Title = "Login"
            redirect_away login_url, :notice=>"Let's get you logged in"
            return true
        else
            return false
        end
    else
       session[:user_id] = session[:user_id] || User.guest_id 
    end
end
=end
    
  def stored_location_for(resource)
    if current_user 
        # flash[:notice] = "Congratulations, you're signed up!"
        if flashback = params[:redirect_to]
            return flashback
        elsif current_user.sign_in_count < 2
            return welcome_path
        else
            return rcpqueries_path
        end
    end
    super( resource ) 
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
end
