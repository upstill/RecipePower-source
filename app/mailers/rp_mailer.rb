class RpMailer < ActionMailer::Base
  # default from: "rpm@recipepower.com"
  add_template_helper(UsersHelper)
  # add_template_helper(TriggersHelper)
  helper TriggersHelper

  def feedback(feedback)
    recipients  = 'recipepowerfeedback@gmail.com'
    subject     = "#{feedback.subject} ##{feedback.id}"

    @feedback = feedback
    mail :to => recipients, :from => @feedback.email, :subject => subject
  end
  
  def welcome_email(user)
    @inviter = user.invited_by
    @login_url  = rp_url '/login'
    mail :to => user.email, :from => 'support@recipepower.com', :subject => 'Welcome to RecipePower'
  end
    
  def invitation_accepted_email invitee
    return unless invitee.invited_by
    @invitee = invitee
    @profile_url = rp_url '/users/profile'
    mail to: invitee.invited_by.email, :from => 'support@recipepower.com', :subject => 'Your invitation was accepted'
  end
  
  # Notify the user via email of a recipe share
  def sharing_notice(notification, opts={})
    @notification = notification
    @recipe = notification.shared
    @sender = notification.source
    @recipient = notification.target
    mail to: @recipient.email, 
      from: @sender.polite_name+" on RecipePower <#{@sender.email}>",
      subject: @sender.polite_name+" has something tasty for you"
  end

  def user_to_user(from, to)
    @sender = from
    @recipient = to
    @body = to.mail_body
    mail to: @recipient.email,
         from: @sender.polite_name+" on RecipePower <#{@sender.email}>",
         subject: to.mail_subject
  end

end
