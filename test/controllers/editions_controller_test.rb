require 'test_helper'

class EditionsControllerTest < ActionController::TestCase
  setup do
    @edition = editions(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:editions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create edition" do
    assert_difference('Edition.count') do
      post :create, edition: { guest_after: @edition.guest_after, guest_before: @edition.guest_before, guest_id: @edition.guest_id, list_after: @edition.list_after, list_after: @edition.list_after, list_before: @edition.list_before, list_before: @edition.list_before, list_id: @edition.list_id, list_id: @edition.list_id, opening: @edition.opening, recipe_after: @edition.recipe_after, recipe_before: @edition.recipe_before, recipe_id: @edition.recipe_id, signoff: @edition.signoff, site_after: @edition.site_after, site_before: @edition.site_before, site_id: @edition.site_id }
    end

    assert_redirected_to edition_path(assigns(:edition))
  end

  test "should show edition" do
    get :show, id: @edition
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @edition
    assert_response :success
  end

  test "should update edition" do
    patch :update, id: @edition, edition: { guest_after: @edition.guest_after, guest_before: @edition.guest_before, guest_id: @edition.guest_id, list_after: @edition.list_after, list_after: @edition.list_after, list_before: @edition.list_before, list_before: @edition.list_before, list_id: @edition.list_id, list_id: @edition.list_id, opening: @edition.opening, recipe_after: @edition.recipe_after, recipe_before: @edition.recipe_before, recipe_id: @edition.recipe_id, signoff: @edition.signoff, site_after: @edition.site_after, site_before: @edition.site_before, site_id: @edition.site_id }
    assert_redirected_to edition_path(assigns(:edition))
  end

  test "should destroy edition" do
    assert_difference('Edition.count', -1) do
      delete :destroy, id: @edition
    end

    assert_redirected_to editions_path
  end
end
