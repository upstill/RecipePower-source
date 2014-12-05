require 'test_helper'

class CollectibleControllerTest < ActionController::TestCase
  test "should get collect" do
    get :collect
    assert_response :success
  end

end
