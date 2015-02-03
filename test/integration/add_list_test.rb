require "test_helper"
class AddListTest < Capybara::Rails::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!

  test "a user can add a list with a new name" do
    tagee = users(:thing3)
    login_as(tagee, scope: :user)
    name = "List Init"
    visit new_list_path(owner_id: tagee.id)
    fill_in "list[name]", with: name
    click_on("Create List")
    @list = List.assert name, tagee
    visit list_path(@list)
    assert_selector("span.tag-filter-title", text: "#{@list.name}")
  end

  test "a user gets an existing list when adding a list using an existing name" do
  end

end