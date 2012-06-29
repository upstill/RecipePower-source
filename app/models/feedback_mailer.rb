class FeedbackMailer < ActionMailer::Base
  default from: "from@example.com"

  def feedback(feedback)
    recipients  = 'feedback@recipepower.com'
    subject     = "[Feedback for RecipePower] #{feedback.subject}"

    @feedback = feedback
    mail(:to => recipients, :subject => subject)
  end
end
