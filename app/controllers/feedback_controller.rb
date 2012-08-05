class FeedbackController < ApplicationController
  layout false

  def new
    @feedback = Feedback.new
    if current_user
        @feedback.email = current_user.email
        @feedback.user_id = current_user.id
    end
  end

  def create
    @feedback = Feedback.create(params[:feedback])
    if @feedback.valid?
      RpMailer.feedback(@feedback).deliver
      render :status => :created, :text => '<h3>Thank you for your feedback!</h3>'
    else
      @error_message = "You can just close the panel if you don't want to describe your #{@feedback.subject.to_s.downcase}."

	  # Returns the whole form back. This is not the most effective
      # use of AJAX as we could return the error message in JSON, but
      # it makes easier the customization of the form with error messages
      # without worrying about the javascript.
      render :action => 'new', :status => :unprocessable_entity
    end
  end
end
