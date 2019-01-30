# require 'test/unit'
require 'test_helper'
require 'results_cache'

class CollectibleTest < ActiveSupport::TestCase
  test "Collecting proceeds" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    # Before preparing the params with a user id, privacy should be off
    refute recipe.collectible_private
    User.current = user
    refute recipe.collectible_private
    recipe.collectible_private = true
    assert_equal true, recipe.collectible_private

    recipe.save
    recipe.reload
    User.current = user
    assert_equal true, recipe.collectible_private

    recipe.collectible_private = false
    assert_equal false, recipe.collectible_private
    recipe.save
    recipe.reload
    User.current = user
    assert_equal false, recipe.collectible_private
  end

  test "Recipe cookmarking" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    User.current = user
    refute recipe.collectible_collected?(user.id)
    assert_equal 0, recipe.num_cookmarks
    recipe.collect
    assert recipe.collectible_collected?(user.id)
    refute recipe.collectible_collected?(users(:thing2).id)
    recipe.save
    assert_equal 1, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
    recipe.collect false
    assert_equal 1, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
    recipe.save
    assert_equal 0, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
    recipe.reload
    assert_equal 0, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
  end

  test "Recipe touching" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    assert_equal 0, recipe.num_cookmarks
    refute recipe.collectible_collected?(user.id)
    User.current = user
    user.touch recipe, false  # Touch but don't collect
    refute recipe.collectible_collected?(user.id)
    recipe.reload
    assert_equal 0, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
  end
end
