require 'test_helper'

class RecipeContentsControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get recipe_contents_edit_url
    assert_response :success
  end

  test "should get patch" do
    get recipe_contents_patch_url
    assert_response :success
  end

  test "should get create" do
    get recipe_contents_create_url
    assert_response :success
  end

  test "should get post" do
    get recipe_contents_post_url
    assert_response :success
  end

  test "should get destroy" do
    get recipe_contents_destroy_url
    assert_response :success
  end

  test "should get show" do
    get recipe_contents_show_url
    assert_response :success
  end

end
