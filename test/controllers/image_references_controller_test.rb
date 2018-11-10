require 'test_helper'

class ImageReferencesControllerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  Warden.test_mode!
  fixtures :users, :image_references
  setup do
    @tagee = users(:thing3)
    login_as(@tagee, scope: :user)
    @image_reference = image_references(:good_url)
  end

  test "should get index" do
    get references_path, format: 'xml'
    assert_response :success
    assert_not_nil assigns(:image_references)
  end

  test "should get new" do
    get new_image_reference_path
    assert_response :success
  end

  test "should create image_reference" do
    # Should 'create' the image_reference by locating the existing image_reference on the identical URL
    count_before = ImageReference.count
    post image_references_path, image_reference: { url: image_references(:good_url).url }
    count_after = ImageReference.count
    assert_equal count_before, count_after

    login_as @tagee, scope: :user
    post image_references_path, image_reference: { url: 'https://homepages.cae.wisc.edu/~ece533/images/airplane.png' }
    count_after = ImageReference.count
    assert_equal count_before+1, count_after
  end

  test "should update image_reference" do
    count_before = ImageReference.count
    reference_attributes = {
        "recipe_id" => recipes(:rcp).id,
        "errcode" => 1,
        "scale_val" => 8,
        'user_id' => 3
    }
    begin
      patch image_reference_path(@image_reference), image_reference: reference_attributes
    rescue Exception => e
      assert_equal e.class, ActionController::UnpermittedParameters
    end
    begin
      patch image_reference_path(@image_reference), image_reference: { } # No go with zero parameters
    rescue Exception => e
      assert_equal e.class, ActionController::ParameterMissing
    end
    @image_reference.reload
    count_after = ImageReference.count
    assert_equal count_before, count_after
    # assert_redirected_to reference_path(assigns(:image_reference))
  end

  test "should show image_reference" do
    get image_reference_path(@image_reference)
    assert_response :success
  end

  test "should get edit" do
    get edit_image_reference_path(@image_reference)
    assert_response :success
  end

  test "should destroy image_reference" do
    assert_difference('ImageReference.count', -1) do
      delete image_reference_path(@image_reference)
    end

    assert_redirected_to references_path
  end
end
