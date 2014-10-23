require 'test/unit'
require 'test_helper'
require 'results_cache'

class CollectibleTest < ActiveSupport::TestCase
  test "Collecting proceeds" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    assert_nil recipe.current_user
    refute recipe.private(user.id)
    refute_nil recipe.current_user # User should be made current by private call
    refute recipe.private
    recipe.private = true
    assert recipe.private
  end

  test "Recipe cookmarking" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    refute recipe.collected_by?(user.id)
    assert 0, recipe.num_cookmarks
    recipe.add_to_collection(user.id)
    assert recipe.collected_by?(user.id)
    assert_equal 1, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
    recipe.remove_from_collection(user.id)
    assert 0, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
  end

  test "Recipe touching" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    assert_nil recipe.touch # Touching without a user does nothing
    assert_equal 0, recipe.num_cookmarks
    refute recipe.collected_by?(user.id)
    recipe.touch false, user.id  # Touch but don't collect
    refute recipe.collected_by?(user.id)
    assert_equal 0, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
  end
end
