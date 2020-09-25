require 'test_helper'
class TrackingTest < ActiveSupport::TestCase

  test "refresh attributes" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url
    assert_equal [:picurl, :title, :description, :content], Recipe.tracked_attributes
    recipe.title_accept 'placeholder' # Set title and flip 'ready' bit
    assert recipe.title_ready
    assert recipe.attrib_ready?(:title)
    refute recipe.title_needed

    # Invalidate the title
    recipe.refresh_attributes :title
    assert recipe.title_needed
    refute recipe.title_ready
    assert_equal [:title], recipe.needed_attributes
    assert_equal [:url, :title], recipe.page_ref.needed_attributes
    recipe.title_accept 'placeholder2' # Set title and flip 'ready' bit

    # Invalidate all the attributes EXCEPT title
    recipe.refresh_attributes except: :title
    assert_equal recipe.needed_attributes, Recipe.tracked_attributes - [:title]
    assert_equal [:url, :title, :picurl, :description].sort, recipe.page_ref.needed_attributes.sort
    assert_equal [:url, :title, :picurl, :description].sort, recipe.page_ref.mercury_result.needed_attributes.sort
    assert_equal [:url, :title, :picurl, :description].sort, recipe.page_ref.gleaning.needed_attributes.sort

    recipe.ensure_attributes # Get the title, etc.
    assert_empty recipe.needed_attributes
    assert_equal recipe.ready_attributes, Recipe.tracked_attributes
    assert_empty recipe.page_ref.needed_attributes
    assert_empty recipe.page_ref.mercury_result.needed_attributes
    assert_empty recipe.page_ref.gleaning.needed_attributes
  end

  test "basic attribute tracking" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url
    assert_equal [:picurl, :title, :description, :content], Recipe.tracked_attributes
    refute recipe.title_needed
    refute recipe.attrib_needed?(:title)
    refute recipe.title_ready
    refute recipe.attrib_ready?(:title)

    recipe.title_accept 'placeholder' # Set title and flip 'ready' bit
    assert recipe.title_ready
    assert recipe.attrib_ready?(:title)
    refute recipe.title_needed
    refute recipe.attrib_needed?(:title)
    assert_equal 'placeholder', recipe.title

    recipe.request_attributes :picurl, :title

    recipe.save
    recipe.reload
    assert recipe.title_ready
    refute recipe.title_needed
    assert_equal 'placeholder', recipe.title

    recipe.ensure_attributes :title, :url # Extract from page_ref
    assert recipe.title_ready
    refute recipe.title_needed

    #recipe.bkg_land
    #assert recipe.page_ref.site
    #recipe.page_ref.site.decorate
    #assert recipe.good?
    #assert_equal 'placeholder', recipe.title  # Immune to gleaning
    #recipe.title = 'replacement'
    #assert_equal 'replacement', recipe.title
  end

end
