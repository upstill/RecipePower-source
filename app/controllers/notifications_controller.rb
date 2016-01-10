class NotificationsController < ApplicationController
  
  # Respond to a link accepting a notification
  # The request must come with an acceptance token which 
  # provides security, and is used to find the notification in question
  def act
    if (token = params[:notification_token]) && (@notification = Notification.find_by_notification_token(token))
      if current_user && (current_user.id != @notification.target_id) && !(@notification.target.aliases_to? current_user)
        # Have to log out the current user and ask for login
        flash[:notice] = "The notice is for #{@notification.target.handle}. Could you please log in as them?"
        sign_out(:user)
      end

      if current_user # Current user matches the notification: just collect the recipe
        @notification.accept
        render :accept, locals: { action_path: NotificationPresenter.new(@notification, view_context, current_user).action_path }
      else # Need to login before anything else
        redirect_to home_path(:notification_token => params[:notification_token]) # This will generate a trigger for the accept after login
      end
    else
      redirect_to home_path, notice: "Sorry, that link was bad."
    end
  end

  def accept
    if (token = params[:notification_token]) && (@notification = Notification.find_by_notification_token(token))
      if current_user # Current user matches the notification: just collect the recipe
        @notification.accept
      else # Need to login before anything else
        redirect_to home_path(:notification_token => params[:notification_token]) # This will generate a trigger for the accept after login
      end
    else
      redirect_to home_path, notice: "Sorry, that link was bad."
    end
  end

end
