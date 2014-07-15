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

  test "initialize a list with empty ordering" do
    lst = List.new
    assert_equal [], lst.ordering, "List doesn't initialize with an empty array"
    assert_equal [], lst.entities, "New list doesn't have empty set of enities"
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

  test "create a list with ordering" do
    tst = List.new
    ordering = tst.ordering
    assert_equal Array, ordering.class, "List ordering should be array after initialization"
    tst.save
    tst.reload
    ordering = tst.ordering
    assert_equal Array, ordering.class,"List ordering should be array after save/restore"
  end

  test "create a list with tags" do
    tagee = users(:thing3)
    lst = List.assert "test list", tagee, create: true
    tag1 = Tag.assert "Tag 1", userid: tagee.id
    tag2 = Tag.assert "Tag 2", userid: tagee.id, tagtype: :Ingredient
    lst.tags = [tag1, tag2]
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
    list = List.assert list_name, tagee
    list.save
    assert_equal list_name, list.name, "new list name not stored"
    list2 = List.assert list_name, tagee
    assert_equal list, list2, "Re-using name tag created a different list"
  end

  test "a list is created with an empty array of entities" do
    list = List.new
    assert_equal [], list.ordering, "List not initialized with empty ordering"
    assert_equal [], list.entities, "List not initialized with empty entities list"
  end

  test "a list accepts recipes" do
    tagee = users(:thing3)
    list_name = "Test List"
    list = List.assert list_name, tagee
    assert_equal [], list.entities, "List not asserted with empty entities list"
    rcp = FactoryGirl.create(:recipe)
    refute list.include?(rcp), "List shouldn't include entity before inclusion"
    list.include rcp
    assert list.include?(rcp), "List should include entity after inclusion"
    list.save
    list.reload
    assert_nil list.ordering.first.entity(false) # Should be restored without the entity
    assert_equal rcp.id, list.ordering.first.id
    assert_equal rcp.class, list.ordering.first.klass
    assert list.include?(rcp), "List should include entity after save and restore"
    assert_equal rcp, list.ordering.first.entity(false) # Should be cached as a side effect of search
    assert_equal rcp, list.entities.first
  end

  test "list serializer returns empty string as empty array" do
    assert_equal [], List::ListSerializer.load("")
    assert_equal [], List::ListSerializer.load(nil)
  end

  test "a list item dumps and loads self without entity" do
    li = List::ListItem.new entity: FactoryGirl.create(:recipe)
    str = List::ListItem.dump li
    li2 = List::ListItem.load str
    assert_equal li.id, li2.id
    assert_equal li.klass, li2.klass
    assert_nil li2.entity(false) # Entity not present a priori
    assert_equal li.entity, li2.entity  # Entity loads
  end

end