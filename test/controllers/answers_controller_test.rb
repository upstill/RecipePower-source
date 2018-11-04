require 'test_helper'
# require Devise::TestHelpers

class AnswersControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :answers, :users
  setup do
    @answer = answers :one
    tagee = users(:thing3)
    login_as(tagee, scope: :user)
  end

  test "should create answer" do
    count_before = Answer.count
    post '/answers', format: 'json', answer: @answer.attributes.slice('user_id', 'question_id', 'answer')
    count_after = Answer.count
    assert_equal count_before, count_after # Successfully matched existing answer
    fbout = Answer.last
    assert_equal fbout, @answer
    assert_equal fbout.attributes.except('id', 'created_at', 'updated_at'), @answer.attributes.except('id', 'created_at', 'updated_at')

    # Now create a slightly different answer
    count_before = Answer.count
    post '/answers',
         format: 'json',
         answer: @answer.attributes.slice('question_id', 'answer').merge(user_id: User.first.id) # Different user, different Answer
    count_after = Answer.count
    assert_equal (count_before+1), count_after # Successfully matched existing answer
    fbout = Answer.last
    assert_not_equal fbout.id, @answer.id
    assert_not_equal fbout.user_id, @answer.user_id
    assert_equal fbout.attributes.except('id', 'created_at', 'updated_at', 'user_id'),
                 @answer.attributes.except('id', 'created_at', 'updated_at', 'user_id')
  end

  test "should update answer" do
    # post '/answers', format: 'json', answer: @answer.attributes.slice('user_id', 'question_id', 'answer')
    patch answer_path(@answer), format: 'json', id: @answer, answer: { user_id: User.first.id }
    @answer.reload
    assert_equal User.first.id, @answer.user_id
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:answers)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should show answer" do
    get :show, id: @answer
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @answer
    assert_response :success
  end

  test "should destroy answer" do
    assert_difference('Edition.count', -1) do
      delete :destroy, id: @answer
    end

    assert_redirected_to answers_path
  end
end
