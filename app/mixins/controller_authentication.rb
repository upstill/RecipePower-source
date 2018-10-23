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
      controller.send :helper_method, :current_user_or_guest_id, :logged_in?
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
end
