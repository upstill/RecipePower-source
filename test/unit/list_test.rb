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

  test "create a list with a tag" do
    tagee = users(:thing3)
    tag = Tag.assert_tag("Test Tag", userid: tagee.id, tagtype: :Collection)
    tst = List.new owner: tagee, tag: tag
    assert_equal tag, tst.tag, "Tag not stored in list"
    tst.save
    tst.reload
    assert_equal tag, tst.tag, "Tag not saved and releaded with list"
  end

  test "create a list with orderings" do
    tst = List.new orderings: []
    orderings = tst.orderings
    assert_equal Array, orderings.class, "List orderings should be array after initialization"
    tst.save
    tst.reload
    orderings = tst.orderings
    assert_equal Array, orderings.class,"List orderings should be array after save/restore"
  end

  # Fake test
  def test_fail

    fail('Not implemented')
  end
end