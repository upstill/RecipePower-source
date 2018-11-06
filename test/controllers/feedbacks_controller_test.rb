require 'test_helper'

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  fixtures :feedbacks
  
  setup do
    @feedback = feedbacks(:one)
  end

  def test_create
    count_before = Feedback.count
    # attr_accessible :id, :user_id, :subject, :email, :comment, :page, :docontact
    post '/feedback', feedback: { user_id: @feedback.user_id,
                                          subject: @feedback.subject,
                                          email: @feedback.email,
                                          comment: @feedback.comment,
                                          page: @feedback.page,
                                          docontact: @feedback.docontact }
    count_after = Feedback.count
    assert_equal (count_before + 1), count_after # Successfully created feedback
    fbout = Feedback.last
    assert_equal fbout.attributes.except('id', 'created_at', 'updated_at'), @feedback.attributes.except('id', 'created_at', 'updated_at')
  end

  test "should show feedback" do
    get :show, id: @feedback
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @feedback
    assert_response :success
  end

  test "should update feedback" do
    patch :update, id: @feedback, feedback: @feedback.attributes.slice('base_id', 'base_type', 'filter', 'results_cache_id', 'results', 'session', 'viewer')
    assert_redirected_to feedback_path(assigns(:feedback))
  end

  test "should destroy feedback" do
    assert_difference('Feedback.count', -1) do
      delete :destroy, id: @feedback
    end

    assert_redirected_to feedbacks_path
  end
end
