require 'test/unit'
require 'test_helper'
require 'results_cache'
class PartitionTest < ActiveSupport::TestCase
  test "Finds the right partition for an index" do
    p = Partition.new [0, 3, 18, 98]
    assert_nil p.partition_of(-2)
    assert_equal 0, p.partition_of(0)
    assert_equal 0, p.partition_of(1)
    assert_equal 0, p.partition_of(2)
    assert_equal 1, p.partition_of(3)
    assert_nil p.partition_of(98)
  end

  test "Degenerate windows handled correctly" do
    p = Partition.new [0, 3, 18, 98]
    p.window = -2..-1
    assert_equal 0..0, p.window
    p.window = -2..8
    assert_equal 0..3, p.window
    p.window = 98..100
    assert_equal 98..98, p.window
    p.window = -2..8
    assert_equal 0..3, p.window
    p.window = 30..100
    assert_equal 30..40, p.window
  end

  test "window defaults to first partition" do
    p = Partition.new [0, 3, 18, 98]
    assert_equal 0..3, p.window
  end

  test "next_index increments correctly" do
    p = Partition.new [0, 3, 18, 98]
    refute p.done?
    assert_equal 0, p.next_index
    refute p.done?
    assert_equal 1, p.next_index
    refute p.done?
    assert_equal 2, p.next_index
    assert p.done?
    assert_nil p.next_index
    assert_equal 3..13, p.next_range
    10.times do
      refute p.done?
      p.next_index
    end
    assert p.done?
  end

  test "Can adjust max window size" do
    p = Partition.new [0, 3, 18, 98]
    p.max_window_size = 15
    p.window = 30..100
    assert_equal 30..45, p.window
  end
end