require File.dirname(__FILE__) + '/../test_helper'
# require File.dirname(__FILE__) + '/../warden_test_helper'

class FeedbackControllerTest < ActionController::TestCase
  include Devise::TestHelpers
  include Warden::Test::Helpers
  Warden.test_mode!
  # include Warden::Test::ControllerHelpers

  def setup
    sign_in User.first
    @controller = FeedbackController.new
    @controller.request = @request = ActionController::TestRequest.create
    # @response   = ActionController::TestResponse.new
  end

  def test_should_have_minimal_feedback_form
    warden
    @request.env["devise.mapping"] = Devise.mappings[:user]
    get :new
    assert_select "form#new_feedback", true do
      assert_select "textarea[name=?]", "feedback[comment]"
      assert_select "[method=?]", 'post'
    end
  end

  def test_should_post_create
    post :create, :feedback => {:comment => "Great website!"}
    assert :success # Doesn't test much
    assert_nil @error_message
  end


  def test_should_set_error_message_when_not_valid
    post :create, :feedback => {:comment => ""}
    assert !assigns(:error_message).blank?
  end

  protected

  def create_feedback(params = {})
    valid_feedback = {
      :subject => "Test",
      :email => "test@yoursite.com",
      :comment => "i like the site"
    }
    Feedback.new(valid_feedback.merge(params))
  end
end
