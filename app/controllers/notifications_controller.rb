class NotificationsController < ApplicationController
  
  # Respond to a link accepting a notification
  # The request must come with an acceptance token which 
  # provides security, and is used to find the 
  def accept
    if note = params[:acceptance_token] && Notification.where(params.slice(:acceptance_token)).first
      if current_user && (current_user.id != note.target_id)
        # Have to log out the current user and ask for login
        sign_out(:user)
      end

      case note.typesym
      when :share_recipe
        redirect_to collect_recipe_path(Recipe.find(note.info[:what]), :uid => note.target_id)
      when :make_friend
      end
      
    else
      redirect_to home_path, notice: "Sorry, that link was bad." 
    end
  end
  
end
