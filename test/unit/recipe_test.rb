require 'test_helper'
require 'list'
class RecipeTest < ActiveSupport::TestCase

  test "gleaning does not happen redundantly" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url, title: 'placeholder'
    assert_equal 'placeholder', recipe.title
    recipe.bkg_land
    assert recipe.site
    recipe.site.decorate
    assert recipe.good?
    assert_not_equal 'placeholder', recipe.title
    recipe.title = 'replacement'
    assert_equal 'replacement', recipe.title
    recipe.bkg_land true
    # Since we forced the gleaning, the title should be replaced
    assert_not_equal 'replacement', recipe.title
  end

  test "url assigned" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url, title: 'placeholder'
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert !recipe.errors.any?
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
    recipe.bkg_launch # Set up the gleaning
    recipe.bkg_land # Ensure it's executed
    assert_equal url, recipe.url
    assert recipe.site.virgin?
    recipe.site.bkg_land
    assert recipe.site.good?
  end

  test "url assigned with successful redirect" do
    url = 'http://patijinich.com/recipe/creamy-poblano-soup/'
    recipe = Recipe.new url: url
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert !recipe.errors.any?
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
    # assert recipe.page_ref.good?
    assert recipe.page_ref.aliases.include?(url) || recipe.url == url
  end

  test "url assigned with unsuccessful redirect" do
    url = 'http://patismexicantable.com/2012/05/creamy-poblano-soup.html'
    recipe = Recipe.new url: url
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
    # assert recipe.page_ref.bad?
    assert recipe.page_ref.aliases.include?(url) || recipe.url == url
  end

  test "blank url rejected" do
    url = ''
    recipe = Recipe.new url: url, title: 'some damn thing'
    assert_nil recipe.page_ref
    assert recipe.errors[:url].present?
    recipe.bkg_land
    assert_nil recipe.page_ref
  end

  test "mal-formed url rejected" do
    url = "nonsense url"
    recipe = Recipe.new url: url
    assert recipe.errors[:url].present?
    recipe.bkg_land
    assert_equal url, recipe.url
    assert recipe.page_ref.bad?
    refute recipe.save
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
  end

  test "bad--but well-formed--url assigned" do
    url = "http://www.tasteofbeirut.com/2013/05/eggplant-in-yogurt-sauce-batenjane-be-laban/"
    recipe = Recipe.new url: url
    assert !recipe.errors.any?
    assert_equal url, recipe.url
    assert recipe.page_ref.virgin?
    recipe.page_ref.bkg_land
    assert recipe.page_ref.bad?
    refute recipe.save
    assert_nil recipe.id
  end

  test "bad url reassigned over good url" do
    good_url = "https://patijinich.com/recipe/creamy-poblano-soup/"
    recipe = Recipe.new title: 'some damn thing', url: good_url
    assert !recipe.errors.any?
    assert recipe.page_ref.virgin?
    assert_equal good_url, recipe.url
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
    assert recipe.save
    assert !recipe.errors.any?
    assert !recipe.page_ref.errors.any?
    assert_not_nil recipe.id
    assert_not_nil recipe.page_ref.id

    bad_url = "https://patijinich.com/2012/05/creamy-poblano-soup.html"
    recipe.url = bad_url
    assert_equal bad_url, recipe.url
    assert !recipe.errors.any?
    recipe.page_ref.bkg_land
    assert recipe.page_ref.bad?

    # Make sure the recipe wasn't saved
    recipe.reload
    assert_equal good_url, recipe.url

  end

  test "url reassigned over bad url" do
    bad_url = "https://patijinich.com/2012/05/creamy-poblano-soup.html"
    recipe = Recipe.new title: 'some damn thing', url: bad_url
    assert !recipe.errors.any?
    assert recipe.page_ref.virgin?
    assert_equal bad_url, recipe.url
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
    assert recipe.save
    assert !recipe.errors.any?
    assert !recipe.page_ref.errors.any?
    assert_not_nil recipe.id
    assert_not_nil recipe.page_ref.id

    good_url = "https://patijinich.com/recipe/creamy-poblano-soup/"
    recipe.url = good_url
    assert_equal good_url, recipe.url
    assert !recipe.errors.any?
    recipe.page_ref.bkg_land
    assert recipe.page_ref.good?

    # Make sure the recipe wasn't saved
    recipe.reload
    assert_equal bad_url, recipe.url
  end
end
