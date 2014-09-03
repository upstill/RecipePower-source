require "test_helper"
class EditListTest < Capybara::Rails::TestCase
  test "a user can edit a list with tags and notes" do
    @owner = users(:thing3)
    name = "List Init"
    subtitle = "A Subtitle"
    visit new_list_path(:owner_id => @owner.id)
    assert_content "New List"
    fill_in "list_name", with: name
    fill_in "list_description", with: subtitle
    click_on("Create List")
    visit lists_path
    @list = List.assert(name, @owner)
    assert_selector("#list_#{@list.id} .name", text: name)
    assert_selector("#list_#{@list.id} .description", text: subtitle)
  end
end