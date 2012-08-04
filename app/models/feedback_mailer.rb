class FeedbackMailer < ActionMailer::Base
  default from: "upstill@gmail.com"

  def feedback(feedback)
    recipients  = 'recipepowerfeedback@gmail.com'
    subject     = "#{feedback.subject} ##{feedback.id}"

    @feedback = feedback
    mail(:to => recipients, :subject => subject)
  end
end
