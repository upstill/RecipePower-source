require 'test_helper'

class SuggestionsControllerTest < ActionController::TestCase
  setup do
    @suggestion = suggestions(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:suggestions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create suggestion" do
    assert_difference('Suggestion.count') do
      post :create, suggestion: { base_id: @suggestion.base_id, base_type: @suggestion.base_type, filter: @suggestion.filter, rc: @suggestion.rc, results: @suggestion.results, session: @suggestion.session, viewer: @suggestion.viewer }
    end

    assert_redirected_to suggestion_path(assigns(:suggestion))
  end

  test "should show suggestion" do
    get :show, id: @suggestion
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @suggestion
    assert_response :success
  end

  test "should update suggestion" do
    patch :update, id: @suggestion, suggestion: { base_id: @suggestion.base_id, base_type: @suggestion.base_type, filter: @suggestion.filter, rc: @suggestion.rc, results: @suggestion.results, session: @suggestion.session, viewer: @suggestion.viewer }
    assert_redirected_to suggestion_path(assigns(:suggestion))
  end

  test "should destroy suggestion" do
    assert_difference('Suggestion.count', -1) do
      delete :destroy, id: @suggestion
    end

    assert_redirected_to suggestions_path
  end
end
