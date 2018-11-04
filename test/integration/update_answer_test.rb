require "test_helper"
class UpdateAnswerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :answers, :users

  setup do
    @answer = answers :one
    tagee = users(:thing3)
    login_as(tagee, scope: :user)
  end

  test "update an answer" do
    patch answer_path(@answer), format: 'json', id: @answer, answer: { user_id: User.first.id }
    @answer.reload
    assert_equal User.first.id, @answer.user_id
  end

end