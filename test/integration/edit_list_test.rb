require "test_helper"
class EditListTest < Capybara::Rails::TestCase
  test "a user can edit a list with tags and notes" do
    name = "List Init"
    visit new_list_path
    fill_in "Name", with: name
    fill_in "Tags", with: "A Subsidiary Tag"
    fill_in "Notes", with: notes_text
    click_on("Create List")
    visit lists_path
    @list = List.find_by_name(name)
    assert_selector("#list_#{@list.id} .name", text: name)
    assert_selector("#list_#{@list.id} .notes", text: notes_text)
  end
end