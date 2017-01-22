require 'test_helper'
require 'list'
class RecipeTest < ActiveSupport::TestCase

  test "url assigned" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert !recipe.errors.any?
    assert recipe.page_ref.good?
    assert_equal url, recipe.url
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
  end

  test "url assigned with successful redirect" do
    url = 'http://patijinich.com/recipe/creamy-poblano-soup/'
    recipe = Recipe.new url: url
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert !recipe.errors.any?
    assert recipe.page_ref.good?
    assert recipe.page_ref.aliases.include?(url) || recipe.url == url
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
  end

  test "url assigned with unsuccessful redirect" do
    url = 'http://patismexicantable.com/2012/05/creamy-poblano-soup.html'
    recipe = Recipe.new url: url
    assert_nil recipe.reference if recipe.respond_to?(:reference)
    assert recipe.page_ref.bad?
    assert recipe.page_ref.aliases.include?(url) || recipe.url == url
    assert_nil recipe.id # No persistence unless asked for
    assert_nil recipe.page_ref.id
  end

  test "blank url rejected" do
    url = ''
    recipe = Recipe.new url: url, title: 'some damn thing'
    assert recipe.page_ref.errors[:url].present?
    assert_equal url, recipe.url
    assert recipe.page_ref.bad?
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
    refute recipe.save
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
    x=2
  end

  test "mal-formed url rejected" do
    url = "nonsense url"
    recipe = Recipe.new url: url
    assert recipe.page_ref.errors[:url].present?
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
    assert recipe.page_ref.bad?
    refute recipe.save
    assert_nil recipe.id
    assert_nil recipe.page_ref.id
  end

  test "bad url reassigned over good url" do
    good_url = "https://patijinich.com/recipe/creamy-poblano-soup/"
    recipe = Recipe.new title: 'some damn thing', url: good_url
    assert !recipe.errors.any?
    assert recipe.page_ref.good?
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
    assert recipe.page_ref.bad?

    # Make sure the recipe wasn't saved
    recipe.reload
    assert_equal good_url, recipe.url

  end

  test "url reassigned over bad url" do
    bad_url = "https://patijinich.com/2012/05/creamy-poblano-soup.html"
    recipe = Recipe.new title: 'some damn thing', url: bad_url
    assert !recipe.errors.any?
    assert recipe.page_ref.bad?
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
    assert recipe.page_ref.good?

    # Make sure the recipe wasn't saved
    recipe.reload
    assert_equal bad_url, recipe.url
  end
end