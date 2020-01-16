require "application_system_test_case"

class RecipePagesTest < ApplicationSystemTestCase
  setup do
    @recipe_page = recipe_pages(:one)
  end

  test "visiting the index" do
    visit recipe_pages_url
    assert_selector "h1", text: "Recipe Pages"
  end

  test "creating a Recipe page" do
    visit recipe_pages_url
    click_on "New Recipe Page"

    fill_in "Text", with: @recipe_page.text
    click_on "Create Recipe page"

    assert_text "Recipe page was successfully created"
    click_on "Back"
  end

  test "updating a Recipe page" do
    visit recipe_pages_url
    click_on "Edit", match: :first

    fill_in "Text", with: @recipe_page.text
    click_on "Update Recipe page"

    assert_text "Recipe page was successfully updated"
    click_on "Back"
  end

  test "destroying a Recipe page" do
    visit recipe_pages_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Recipe page was successfully destroyed"
  end
end
