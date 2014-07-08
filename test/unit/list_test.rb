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

  test "create a list with a name tag" do
    tagee = users(:thing3)
    tag = Tag.assert("Test Tag", userid: tagee.id, tagtype: :Collection)
    tst = List.new owner: tagee, name_tag: tag
    assert_equal tag, tst.name_tag, "Name tag not stored in list"
    tst.save
    tst.reload
    assert_equal tag, tst.name_tag, "Name tag not saved and releaded with list"
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

  test "create a list with tags" do
    tagee = users(:thing3)
    lst = List.new orderings: []
    tag1 = Tag.assert "Tag 1", userid: tagee.id
    tag2 = Tag.assert "Tag 2", userid: tagee.id, tagtype: :Ingredient
    lst.tags << tag1
    lst.tags << tag2
    assert_equal tag1, lst.tags.first, "First tag not attached to list after assignment"
    assert_equal tag2, lst.tags.last, "Last tag not attached to list after assignment"
    lst.save
    lst.reload
    assert_equal tag1, lst.tags.first, "First tag not attached to list after save and restore"
    assert_equal tag2, lst.tags.last, "Last tag not attached to list after save and restore"
  end

  test "create a list with notes" do
    lst = List.new
    assert_equal "", lst.notes, "Notes don't default to empty string"
    note = "This should be a note"
    lst.notes = note
    assert_equal note, lst.notes, "Notes not stored"
    lst.save
    lst.reload
    assert_equal note, lst.notes, "Notes not saved and restored"
  end

  test "create a list with a name string" do
    tagee = users(:thing3)
    list_name = "Test List"
    list = List.assert( list_name, user: tagee )
    list.save
    assert_equal list_name, list.name, "new list name not stored"
    list2 = List.assert( list_name, user: tagee )
    assert_equal list, list2, "Re-using name tag created a different list"
  end

end