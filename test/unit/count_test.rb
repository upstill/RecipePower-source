require 'test/unit'
require 'test_helper'
require 'results_cache'
class AssociationTest < ActiveSupport::TestCase
  test "Count increments scalars" do
    count = Counts.new
    assert_equal 0, count[:a]
    count.incr :a
    assert_equal 1, count[:a]
    count.incr :a
    assert_equal 2, count[:a]
    count.incr :a, 10
    assert_equal 12, count[:a]
  end

  test "Count increments arrays" do
    count = Counts.new
    assert_equal 0, count[:a]
    count.incr [:a, :b]
    assert_equal 1, count[:a]
    assert_equal 1, count[:b]
    count.incr [:a, :b]
    assert_equal 2, count[:a]
    assert_equal 2, count[:b]
    count.incr [:a,:b,:c], 10
    assert_equal 12, count[:a]
    assert_equal 12, count[:b]
    assert_equal 10, count[:c]
  end

end