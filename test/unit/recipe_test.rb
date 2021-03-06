require 'test_helper'
require 'list'
class RecipeTest < ActiveSupport::TestCase

  test "gleaning does not happen redundantly" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url, title: 'placeholder'
    assert_equal 'placeholder', recipe.title
    recipe.bkg_land
    assert recipe.page_ref.site
    recipe.page_ref.site.decorate
    assert recipe.good?
    assert_equal 'placeholder', recipe.title  # Immune to gleaning
    recipe.title = 'replacement'
    assert_equal 'replacement', recipe.title
  end

  test "url assigned" do
    url = "https://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url, title: 'placeholder'
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert !recipe.errors.present?
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
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
    assert !recipe.errors.present?
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
    # assert recipe.page_ref.good?
    assert recipe.page_ref.alias_for?(url) || recipe.url == url
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
    refute recipe.errors[:url].present? # Bogus URL is at least assignable
    assert_equal url, recipe.url
    recipe.bkg_land
    assert recipe.page_ref.bad?
    refute recipe.save
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
  end

  test "bad--but well-formed--url assigned" do
    url = "http://www.tastenobeirut.com/2013/05/eggplant-in-yogurt-sauce-batenjane-be-laban/"
    recipe = Recipe.new url: url
    assert !recipe.errors.present?
    assert_equal url, recipe.url
    assert recipe.page_ref.virgin?
    recipe.ensure_attributes :title, :description
    refute recipe.attrib_ready?(:description)
    refute recipe.attrib_ready?(:title)
    assert recipe.page_ref.bad?
    refute recipe.save
    assert_nil recipe.id
  end
  test "recipe with redirect responds to all aliases" do
    url = "http://www.tasteofbeirut.com/2013/05/eggplant-in-yogurt-sauce-batenjane-be-laban/"
    recipe = Recipe.new url: url
    assert !recipe.errors.present?
    assert_equal url, recipe.url
    assert recipe.page_ref.virgin?
    recipe.ensure_attributes :title, :description
    assert recipe.attrib_ready?(:description)
    assert recipe.attrib_ready?(:title)
    assert recipe.page_ref.good?
    assert_equal 'https://www.tasteofbeirut.com/eggplant-in-yogurt-sauce-batenjane-be-laban/', recipe.url
    assert_equal recipe.picture, recipe.page_ref.picture # Identical unpersisted ImageReferences
    assert recipe.save
    assert_not_nil recipe.id
    recipe.save
    recipe.reload
    assert_equal recipe, Recipe.find_by_url('https://www.tasteofbeirut.com/2013/05/eggplant-in-yogurt-sauce-batenjane-be-laban/')
    assert_equal recipe, Recipe.find_by_url('http://www.tasteofbeirut.com/2013/05/eggplant-in-yogurt-sauce-batenjane-be-laban/')
    assert_equal 'https://www.tasteofbeirut.com/wp-content/uploads/2013/05/eggplant-in-yogurt-sauce1.jpg', recipe.picurl
  end

  test "bad url reassigned over good url" do
    good_url = "https://patijinich.com/creamy-poblano-soup/"
    recipe = Recipe.new title: 'some damn thing', url: good_url
    assert recipe.errors.empty?
    assert recipe.page_ref.virgin?
    assert_equal good_url, recipe.url
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
    assert recipe.save
    assert recipe.errors.empty?
    assert recipe.page_ref.errors.empty?
    assert_not_nil recipe.id
    assert_not_nil recipe.page_ref.id

    bad_url = "https://patijinich.com/2012/05/creamy-poblano-soup.html"
    recipe.url = bad_url
    assert_equal bad_url, recipe.url
    recipe.save # Should launch the page_ref
    assert recipe.page_ref.virgin?
    recipe.page_ref.bkg_land
    assert recipe.page_ref.bad?
    assert recipe.page_ref.error_message.present?
    assert recipe.errors.empty?
    recipe.bkg_land
    assert recipe.bad?
  end

  test "url reassigned over bad url" do
    bad_url = "https://patijinich.com/2012/05/creamy-poblano-soup.html"
    recipe = Recipe.new title: 'some damn thing', url: bad_url
    assert recipe.errors.empty?
    assert recipe.page_ref.virgin?
    assert_equal bad_url, recipe.url
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
    assert recipe.save
    assert recipe.errors.empty?
    assert !recipe.page_ref.errors.present?
    assert_not_nil recipe.id
    assert_not_nil recipe.page_ref.id

    good_url = "https://patijinich.com/creamy-poblano-soup/"
    recipe.url = good_url
    assert_equal good_url, recipe.url
    assert recipe.errors.empty?
    recipe.page_ref.bkg_land
    assert recipe.page_ref.good?
  end
end
