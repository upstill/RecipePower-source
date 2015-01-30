require 'test/unit'
require 'test_helper'
require 'results_cache'

class CollectibleTest < ActiveSupport::TestCase
  test "Collecting proceeds" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    # Before preparing the params with a user id, privacy should be off
    refute recipe.private
    recipe.uid = user.id
    refute recipe.private
    recipe.private = true
    assert_equal true, recipe.private

    recipe.save
    recipe.reload
    recipe.uid = user.id
    assert_equal true, recipe.private

    recipe.private = false
    recipe.save
    recipe.reload
    recipe.uid = user.id
    assert_equal false, recipe.private
  end

  test "Recipe cookmarking" do
    recipe = recipes(:rcp)
    user = users(:thing1)
    recipe.uid = user.id
    refute recipe.collected?(user.id)
    assert_equal 0, recipe.num_cookmarks
    recipe.collect
    assert recipe.collected?
    refute recipe.collected?(users(:thing2).id)
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
    refute recipe.collected?(user.id)
    recipe.uid = user.id
    recipe.touch false  # Touch but don't collect
    refute recipe.collected?(user.id)
    recipe.reload
    assert_equal 0, recipe.num_cookmarks # Should have been remembered as viewed, but not cookmarked
  end
end
