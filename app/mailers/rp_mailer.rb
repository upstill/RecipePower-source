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

  def user_to_user(from, to)
    @sender = from
    @recipient = to
    @body = to.mail_body
    mail to: @recipient.email,
         from: @sender.polite_name+" on RecipePower <#{@sender.email}>",
         subject: to.mail_subject
  end

end
