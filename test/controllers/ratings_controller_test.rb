require 'test_helper'

class RatingsControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :users, :ratings
  setup do
    @tagee = users(:thing3)
    login_as(@tagee, scope: :user)
    @rating = ratings(:test)
  end

  test "should get index" do
    get ratings_path, format: 'xml'
    assert_response :success
    assert_not_nil assigns(:ratings)
  end

  test "should get new" do
    get new_rating_path
    assert_response :success
  end

  test "should create rating" do
    count_before = Rating.count
    rating_attributes = {
        "recipe_id" => recipes(:rcp).id,
        "scale_id" => 1,
        "scale_val" => 8,
        'user_id' => 3
    }
    begin
      post ratings_path, rating: rating_attributes
    rescue Exception => e
      assert_equal e.class, ActionController::UnpermittedParameters
    end

    login_as(@tagee, scope: :user)
    rating_attributes.delete 'user_id'
    post ratings_path, rating: rating_attributes # Should accept everything else

    rating = Rating.last
    count_after = Rating.count
    assert_equal count_before+1, count_after
    assert_equal rating_attributes['recipe_id'], rating.recipe_id
    assert_equal rating_attributes['scale_id'], rating.scale_id
    assert_equal rating_attributes['scale_val'], rating.scale_val
    assert_equal @tagee.id, rating.user_id
  end

  test "should update rating" do
    count_before = Rating.count
    rating_attributes = {
        "recipe_id" => recipes(:rcp).id,
        "scale_id" => 1,
        "scale_val" => 8
    }
    patch rating_path(@rating), rating: rating_attributes
    @rating.reload
    count_after = Rating.count
    assert_equal count_before, count_after
    assert_equal rating_attributes['recipe_id'], @rating.recipe_id
    assert_equal rating_attributes['scale_id'], @rating.scale_id
    assert_equal rating_attributes['scale_val'], @rating.scale_val
    # assert_redirected_to rating_path(assigns(:rating))
  end

  test "should show rating" do
    get rating_path(@rating)
    assert_response :success
  end

  test "should get edit" do
    get edit_rating_path(@rating)
    assert_response :success
  end

  test "should destroy rating" do
    assert_difference('Rating.count', -1) do
      delete rating_path(@rating)
    end

    assert_redirected_to ratings_path
  end
end
