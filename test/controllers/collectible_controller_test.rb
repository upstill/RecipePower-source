require 'test_helper'
require 'warden_test_helper'

class CollectibleControllerTest < ActionController::TestCase
  test "should get collect" do
    get :collect
    assert_response :success
  end

end
