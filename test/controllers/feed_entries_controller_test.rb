require 'test_helper'

class FeedEntriesControllerTest < ActionController::TestCase
  test "should post collect" do
    post :collect
    assert_response :success
  end

end
