require 'test/unit'
require 'test_helper'
class ListTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test "create a list with an owner"  do
    tagee = users(:thing3)
    tst = List.new owner: tagee
    assert_equal tagee, tst.owner, "List owner not stored"
    tst.save
    tst.reload
    assert_equal tagee, tst.owner, "List owner not saved and restored"
  end

  test "create a list with items" do
    tst = List.new items: []
    items = tst.items
    assert_equal Array, items.class, "List items should be array after initialization"
    tst.save
    tst.reload
    items = tst.items
    assert_equal Array, items.class,"List items should be array after save/restore"
  end

  # Fake test
  def test_fail

    fail('Not implemented')
  end
end