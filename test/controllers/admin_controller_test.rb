require 'test_helper'
require 'warden_test_helper'

class AdminControllerTest < ActionController::TestCase

  test "should get toggle" do
    get :toggle
    assert_response :success
  end

end
