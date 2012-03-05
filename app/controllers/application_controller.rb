require './lib/controller_authentication.rb'

class ApplicationController < ActionController::Base
    helper :all
    
    helper_method :orphantagid
    
    def orphantagid(tagid)
        "orphantag_"+tagid.to_s
    end
    
  include ControllerAuthentication
  protect_from_forgery

# Gateway to (most) controllers: check that there's a current user
# and don't do anything until there is one. If login isn't required,
# set the session user id to guest
def need_login(login_required, super_required = false)
    if(login_required)
        if super_required
            if session[:user_id] != User.super_id
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

  # redirect somewhere that will eventually return back to here
  def redirect_away(*params)
    session[:original_uri] = request.url
    redirect_to(*params)
  end

  # returns the person to either the original url from a redirect_away or to a default url
  def redirect_back(*params)
    uri = session[:original_uri]
    session[:original_uri] = nil
    if uri
      redirect_to uri
    else
      redirect_to(*params)
    end
  end
end
