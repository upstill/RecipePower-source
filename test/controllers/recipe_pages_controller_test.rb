require 'test_helper'

class RecipePagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recipe_page = recipe_pages(:one)
  end

  test "should get index" do
    get recipe_pages_url
    assert_response :success
  end

  test "should get new" do
    get new_recipe_page_url
    assert_response :success
  end

  test "should create recipe_page" do
    assert_difference('RecipePage.count') do
      post recipe_pages_url, params: { recipe_page: { text: @recipe_page.text } }
    end

    assert_redirected_to recipe_page_url(RecipePage.last)
  end

  test "should show recipe_page" do
    get recipe_page_url(@recipe_page)
    assert_response :success
  end

  test "should get edit" do
    get edit_recipe_page_url(@recipe_page)
    assert_response :success
  end

  test "should update recipe_page" do
    patch recipe_page_url(@recipe_page), params: { recipe_page: { text: @recipe_page.text } }
    assert_redirected_to recipe_page_url(@recipe_page)
  end

  test "should destroy recipe_page" do
    assert_difference('RecipePage.count', -1) do
      delete recipe_page_url(@recipe_page)
    end

    assert_redirected_to recipe_pages_url
  end
end
