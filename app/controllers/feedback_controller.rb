class FeedbackController < ApplicationController
  layout false

  def new
    @feedback = Feedback.new
    if current_user
        @feedback.email = current_user.email
        @feedback.user_id = current_user.id
    end
    smartrender
  end

  def create
    @feedback = Feedback.create feedback_params
    if @feedback.valid?
      RpMailer.feedback(@feedback).deliver
      render json: { done: true, notice: "Thank you again!" }
    else
      @error_message = "You can just close the panel if you don't want to describe your #{@feedback.subject.to_s.downcase}."

	  # Returns the whole form back. This is not the most effective
      # use of AJAX as we could return the error message in JSON, but
      # it makes easier the customization of the form with error messages
      # without worrying about the javascript.
      smartrender :action => 'new', :status => :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit :user_id, :subject, :email, :comment, :page, :docontact
  end
end
