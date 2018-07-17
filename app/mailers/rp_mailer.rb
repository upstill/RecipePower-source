class RpMailer < ActionMailer::Base
  add_template_helper EditionsHelper
  add_template_helper UsersHelper
  add_template_helper LinkHelper
  # add_template_helper ItemHelper
  # add_template_helper BootstrapHelper
  add_template_helper EmailHelper
  # default from: "rpm@recipepower.com"
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

  def newsletter edition, recipient
    @edition = edition
    @recipient = recipient
    @markdown = Redcarpet::Markdown.new Redcarpet::Render::HTML
    @unsubscribe = Rails.application.message_verifier(:unsubscribe).generate(@recipient.id)
    mail :to => recipient.email, :from => 'recipepowerfeedback@gmail.com', :subject => edition.banner
  end

end
