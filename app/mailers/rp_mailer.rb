class RpMailer < ActionMailer::Base
  # default from: "rpm@recipepower.com"
  add_template_helper(UsersHelper)
  
  def feedback(feedback)
    recipients  = 'recipepowerfeedback@gmail.com'
    subject     = "#{feedback.subject} ##{feedback.id}"

    @feedback = feedback
    mail :to => recipients, :from => @feedback.email, :subject => subject
  end
  
  def welcome_email(user)
    @inviter = User.where(id: user.invited_by).first
    @user = user
    @profile_url = "http://www.recipepower.com/users/profile"
    @login_url  = "http://recipepower.com/login"
    mail :to => @user.email, :from => "support@recipepower.com", :subject => "Welcome to RecipePower"
  end
    
  def invitation_accepted_email(invitee)
    return unless @user = User.where(id: invitee.invited_by).first
    @invitee = invitee
    @profile_url = "http://www.recipepower.com/users/profile"
    mail to: @user.email, :from => "support@recipepower.com", :subject => "Your invitation was accepted"
  end
  
  # Notify the user via email of a recipe share
  def sharing_notice(notification, opts={})
    @notification = notification
    @recipe = Recipe.find(notification.info[:what])
    @sender = notification.source
    @recipient = notification.target
    mail to: @recipient.email, 
      from: @sender.polite_name+" on RecipePower <#{@sender.email}>",
      subject: @sender.polite_name+" has something tasty for you"
  end
end
