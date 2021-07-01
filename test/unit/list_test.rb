# require 'test/unit'
require 'test_helper'
require 'list'
class ListTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    super
    @owner = users(:thing3)
    @lst_name = "Test List" # From tags.yml
    @description = "A list strictly for testing purposes"  # From lists.yml
    @lst = List.assert @lst_name, @owner # , description: @description
    # Get a recipe under a tag
    @lst.store (@included = FactoryBot.create(:recipe))
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test "a list is initialized with empty ordering" do
    lst = List.new
    assert_equal [], lst.ordering, "List doesn't initialize with an empty array"
    assert_equal [], lst.entities, "New list doesn't have empty set of entities"
  end

  test "a list creates, saves and restores the ordering" do
    tst = List.new
    ordering = tst.ordering
    assert_equal Array, ordering.class, "List ordering should be array after initialization"
    tst.save
    tst.reload
    assert_equal Array, tst.ordering.class,"List ordering should be array after save/restore"
  end

  test "a list accepts, saves and restores an owner"  do
    tst = List.new owner: @owner
    assert_equal @owner, tst.owner, "List owner not stored"
    tst.save
    tst.reload
    assert_equal @owner, tst.owner, "List owner not saved and restored"
  end

  test "a list accepts, saves and restores a name tag" do
    tag = Tag.assert("Test Tag", :Collection, userid: @owner.id )
    tst = List.new owner: @owner, name_tag: tag
    assert_equal tag, tst.name_tag, "Name tag not stored in list"
    tst.save
    tst.reload
    assert_equal tag, tst.name_tag, "Name tag not saved and reloaded with list"
  end

  test "a list has a unique name string" do
    assert_equal @lst_name, @lst.name, "new list name not stored"
    assert_equal @lst_name, @lst.name_tag.name, "Name not stored in tag"
    @lst.save
    @lst.reload
    assert_equal @lst_name, @lst.name, "Name tag not saved and reloaded with list"
    assert_equal @lst_name, @lst.name_tag.name, "Name tag not saved and reloaded with list"

    # Do redundancy check
    list2 = List.assert @lst_name, @owner
    assert_equal @lst, list2, "Re-using name tag created a different list"
  end

  test "create a list with notes" do
    assert_equal "", @lst.notes, "Notes don't default to empty string"
    note = "This should be a note"
    @lst.notes = note
    assert_equal note, @lst.notes, "Notes not stored"
    @lst.save
    @lst.reload
    assert_equal note, @lst.notes, "Notes not saved and restored"
  end

  test "create a list with a description" do
    assert_equal "", @lst.description, "Description doesn't default to empty string"
    @lst.description = @description
    assert_equal @description, @lst.description, "Description not stored"
    @lst.save
    @lst.reload
    assert_equal @description, @lst.description, "Description not saved and restored"
  end

  test "a list is created with an empty array of entities" do
    list = List.new
    assert_equal [], list.ordering, "List not initialized with empty ordering"
    assert_equal [], list.entities, "List not initialized with empty entities list"
  end

  test "list serializer returns empty string as empty array" do
    assert_equal [], ListSerializer.load("")
    assert_equal [], ListSerializer.load(nil)
  end

  test "a list item dumps and loads self without entity" do
    li = ListItem.new entity: FactoryBot.create(:recipe)
    str = ListItem.dump li
    li2 = ListItem.load str
    assert_equal li.id, li2.id
    assert_equal li.klass, li2.klass
    assert_nil li2.entity(false) # Entity not present a priori
    assert_equal li.entity, li2.entity  # Entity loads
  end

=begin
  test "a newly-added list appears in the user's browser" do
    assert @owner.browser.select_by_content(@lst.name_tag)
  end
=end

end
