# This module is included in your application controller which makes
# several methods available to all controllers and views. Here's a
# common example you might add to your application layout file.
#
#   <% if logged_in? %>
#     Welcome <%= current_user.username %>.
#     <%= link_to "Edit profile", edit_current_user_path %> or
#     <%= link_to "Log out", logout_path %>
#   <% else %>
#     <%= link_to "Sign up", signup_path %> or
#     <%= link_to "log in", login_path %>.
#   <% end %>
#
# You can also restrict unregistered users from accessing a controller using
# a before filter. For example.
#
#   before_filter :login_required, :except => [:index, :show]
module ControllerAuthentication
  def self.included(controller)
      controller.send :helper_method, :current_user_or_guest_id, :logged_in?, :redirect_to_target_or_default
      # controller.send :helper_method, :current_user, :logged_in?, :redirect_to_target_or_default
  end
  
  def current_user_or_guest
      current_user || User.guest
  end
  
  def current_user_or_guest_id
    self.current_user_or_guest.id
  end

  def logged_in?
    current_user != nil
  end

  # before_filter on controller that needs login to do anything
  def login_required(alert = "Let's get you logged in so we can do this properly.")
    unless logged_in?
      scope = Devise::Mapping.find_scope!(User)
      session["#{scope}_return_to"] = request.url 
      flash[:alert] = alert
      redirect_to new_authentication_path # login_url, :alert => alert
    end
  end

  def redirect_to_target_or_default(default, *args)
    redirect_to(session[:return_to] || default, *args)
    session[:return_to] = nil
  end

  private

  def store_target_location
    session[:return_to] = request.url
  end
end
