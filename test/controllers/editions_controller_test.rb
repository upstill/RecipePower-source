require 'test_helper'

class EditionsControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :editions, :users
  setup do
    tagee = users(:thing3)
    login_as(tagee, scope: :user)
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
    count_before = Edition.count
    # post '/editions', edition: @edition.attributes
    post '/editions', edition: @edition.attributes.slice( 'signoff',
        'guest_before', 'guest_after', 'guest_id', 'guest_type',
        'recipe_before', 'recipe_after', 'recipe_id',
        'list_before', 'list_after', 'list_id',
        'site_before', 'site_after', 'site_id' ).merge('opening' => 'Special Opening')
    edition = Edition.last
    count_after = Edition.count
    assert_equal count_before+1, count_after
  end

  test "should update edition" do
    refute @edition.published
    # A commit (submit button title) that includes 'Publish' is the signal to flip Published on
    patch edition_path(@edition), commit: 'Publish', edition: { 'opening' => 'Special Opening' }
    @edition.reload
    assert @edition.published
    assert_redirected_to edition_path(assigns(:edition))
  end

  test "should show edition" do
    get 'show', id: @edition
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @edition
    assert_response :success
  end

  test "should destroy edition" do
    assert_difference('Edition.count', -1) do
      delete :destroy, id: @edition
    end

    assert_redirected_to editions_path
  end
end
