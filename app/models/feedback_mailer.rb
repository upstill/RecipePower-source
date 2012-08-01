class FeedbackMailer < ActionMailer::Base
  default from: "recipepowerfeedback@gmail.com"

  def feedback(feedback)
    recipients  = 'upstill@gmail.com'
    subject     = "#{feedback.subject} ##{feedback.id}"

    @feedback = feedback
    mail(:to => recipients, :subject => subject)
  end
end
