# encoding: UTF-8
require 'test_helper'
require 'warden_test_helper'

class ListsControllerTest < ActionController::TestCase
  test "should collect querytags" do
    get :index, querytags: "yeltsin"
    assert_response :success
    assert_equal "yeltsin", @controller.querytags.first.name
    assert_equal "yeltsin", session[:querytags]["-1"]

    get :index, querytags: "-1"
    assert_equal "yeltsin", @controller.querytags.first.name
    assert_equal "yeltsin", session[:querytags]["-1"]
  end
end