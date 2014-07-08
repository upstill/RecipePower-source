require "test_helper"
class AddListTest < Capybara::Rails::TestCase
  test "a user can add a list with a new name" do
    tagee = users(:thing3)
    name = "List Init"
    visit new_list_path
    fill_in "Name", with: name
    click_on("Create List")
    visit lists_path
    @list = List.assert(name)
    assert_selector("#list_#{@list.id} .name", text: name)
    assert_selector("#list_#{@list.id} .notes", text: notes_text)
  end
  test "a user gets an existing list when adding a list using an existing name" do

  end
end