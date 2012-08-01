class RpMailer < ActionMailer::Base
  default from: "upstill@gmail.com"
  def welcome_email(user)
      @user = user
      @url  = "http://recipepower.com/login"
      mail(:to => user.email, :subject => "Welcome to RecipePower")
    end
    
  def invitation_accepted_email(invitee)
    return unless @user = User.where(id: invitee.invited_by).first
    @invitee = invitee
    @url = "http://www.recipepower.com/users/profile"
    mail to: @user.email, :subject => "Your invitation was accepted"
  end
end
