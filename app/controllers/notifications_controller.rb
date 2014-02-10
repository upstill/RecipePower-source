class NotificationsController < ApplicationController
  
  # Respond to a link accepting a notification
  # The request must come with an acceptance token which 
  # provides security, and is used to find the 
  def accept
    if token = params[:notification_token] # defer_notification 
      note = Notification.find_by_notification_token(token)
      if current_user && (current_user.id != note.target_id)
        # Have to log out the current user and ask for login
        flash[:notice] = "The notice is for #{note.target.handle}. Could you please log in as them?"
        sign_out(:user)
      end

      case note.typesym
      when :share_recipe
        # Add the recipe to the user's collection and go to the collection
        if current_user # Current user matches the notification: just collect the recipe
          note.accept
          redirect_to collect_recipe_path(Recipe.find(note.info[:what]), :uid => note.target_id)
        else # Need to login before anything else
          redirect_to home_path(:notification_token => params[:notification_token]) # This will generate a trigger for the accept after login
        end
      when :make_friend
      end
      
    else
      redirect_to home_path, notice: "Sorry, that link was bad." 
    end
  end
  
end
