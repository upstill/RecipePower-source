require 'test_helper'

class ResultsCacheTest < ActiveSupport::TestCase

  def setup
    Tag.delete_all
    Expression.delete_all
    Reference.delete_all
    Referent.delete_all
    Recipe.delete_all
  end

  test 'ingredient_test_extracts_correct_data' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/candied_peel', false
    scraper.perform_naked
    # After scraping the page, there should be a SINGLE 'candied peel' tag, with corresponding expression, referent and ImageReference
    assert_equal 1, Tag.count
    assert_equal 'candied peel', Tag.first.name
    assert_equal 1, Referent.count
    assert_equal 1, ImageReference.count
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_608/foods/c/candied_peel_16x9.jpg', ImageReference.first.url
    assert_equal 1, Expression.count

    # Check that the referent got the image
    referent = Tag.first.referents.first
    assert_equal ImageReference.first, referent.picture

    # Rerun the scraper to ensure that no tags, etc. get created redundantly
    scraper2 = Scraper.assert 'http://www.bbc.co.uk/food/candied_peel', false
    assert_equal scraper, scraper2
    scraper2.perform_naked
    assert_equal 1, Tag.count
    assert_equal 'candied peel', Tag.first.name
    assert_equal 1, Referent.count
    assert_equal 1, ImageReference.count
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_608/foods/c/candied_peel_16x9.jpg', ImageReference.first.url
    assert_equal 1, Expression.count
    referent = Tag.first.referents.first
    assert_equal ImageReference.first, referent.picture
    assert_equal referent.picture, ImageReference.first

    # Confirm that destroying the image removes the picture from the referent
    ImageReference.first.destroy
    referent.reload
    assert_nil referent.picture

    referent.destroy
    assert_equal 0, Referent.count
    assert_equal 0, Expression.count
    assert_equal 0, Tag.first.expressions.count
    assert_equal 0, Tag.first.referents.count

  end

  test 'bbc_chef_page' do
    url = 'http://www.bbc.co.uk/food/chefs/antonio_carluccio'
    scraper = Scraper.assert url, false
    scraper.perform_naked
    dr = DefinitionReference.first
    assert_equal url, dr.url

    assert_equal 1, Tag.count
    ats = Tag.where tagtype: Tag.typenum(:Author)
    at = ats.first
    assert_equal 1, ats.count
    assert_equal 'Antonio Carluccio', at.name
    assert_equal 1, AuthorReferent.count
    ar = AuthorReferent.first
    assert_equal dr, ar.references.first
    assert_equal ar, at.referents.first
    assert_equal at, ar.tags.first
    assert_equal 'Antonio Carluccio', at.name
    assert ar.description.match('Antonio Carluccio is a leading authority on Italian cooking')

  end

  test 'bbc_chefs_recipes_page' do
    url = 'http://www.bbc.co.uk/food/recipes/search?chefs[]=antonio_carluccio'
    scraper = Scraper.assert url, true
    scraper.perform_naked

    # Should have defined the author tag
    ats = Tag.where tagtype: Tag.typenum(:Author)
    at = ats.first
    assert_equal 1, ats.count
    assert_equal 'Antonio Carluccio', at.name
    assert_equal 'http://www.bbc.co.uk/food/chefs/antonio_carluccio', DefinitionReference.first.url

    assert_equal 15, Recipe.count
    assert_equal 'Slow-cooked family stew with polenta', Recipe.first.title
    assert_equal 15, at.recipes.count # They should all be tagged with the
    assert_equal 17, Scraper.count # Launched scrapers for each recipe and the Next page
  end

  test 'bbc_recipe_page' do
    url = 'http://www.bbc.co.uk/food/recipes/lemon_and_ricotta_tart_44080'
    r1 = CollectibleServices.find_or_create({ url: url }, { 'Title' => 'Lemon and ricotta tart' }, Recipe)
    scraper = Scraper.assert url, false
    scraper.perform_naked

    assert_equal 1, Recipe.count
    r = Recipe.first
    assert_equal r, r1
    assert_equal 'Lemon and ricotta tart', r.title
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_448/recipes/lemon_and_ricotta_tart_44080_16x9.jpg', r.picurl
    assert r.description.match('This easy lemon tart is delicious')

    author_tags = Tag.where(tagtype: 7)
    assert_equal 1, author_tags.count
    assert_equal 'Antonio Carluccio', author_tags.first.name

    ingredient_tags = Tag.where(tagtype: 4)
    assert_equal 8, ingredient_tags.count
    tag_names = %w{ puff\ pastry plain\ flour eggs ricotta lemon mascarpone candied\ peel caster\ sugar }
    ingredient_tags.each { |it|
      assert tag_names.include?(it.name)
      assert (it.recipes.to_a == [r])
    }
  end

  test 'bbc_seasons_atoz_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/recipes/lemon_and_ricotta_tart_44080', false
    scraper.perform_naked
  end

  test 'bbc_seasons_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/seasons', false
    scraper.perform_naked

    assert_equal 12, Tag.where(tagtype: 8).count
    assert_equal 'January', Tag.where(tagtype: 8).first.name

    assert_equal 'http://www.bbc.co.uk/food/seasons/january', DefinitionReference.first.url
    assert_equal 12, DefinitionReference.count
    assert_equal 12, ImageReference.count
    assert_equal 12, OccasionReferent.count
    occr = OccasionReferent.first
    assert_equal ImageReference.first, occr.picture
    assert_equal 'http://ichef.bbci.co.uk/food/ic/food_16x9_235/seasons/january_16x9.jpg', occr.picurl
  end

  test 'bbc_season_page' do
    scraper = Scraper.assert 'http://www.bbc.co.uk/food/seasons/january', false

    # We're going to go through this twice, the second time to confirm that redundancy was avoided
    scraper.perform_naked
    assert_equal 1, Tag.where(tagtype: 8).count
    month_tag = Tag.where(tagtype: 8).first
    assert_equal 'January', month_tag.name
    # Scrape the 'January' page and confirm results
    # ---- 32 recipes
    assert_equal 36, Recipe.count
    assert_equal 36, month_tag.taggings.count
    # ---- 22 seasonal ingredients
    assert_equal 1, OccasionReferent.count
    assert_equal 22, Tag.where(tagtype: 4).count
    assert_equal 22, month_tag.referents.first.ingredient_referents.count

    # Second time around...
    scraper.perform_naked
    assert_equal 1, Tag.where(tagtype: 8).count
    month_tag = Tag.where(tagtype: 8).first
    assert_equal 'January', month_tag.name
    # Scrape the 'January' page and confirm results
    # ---- 32 recipes
    assert_equal 36, Recipe.count
    assert_equal 36, month_tag.taggings.count
    # ---- 22 seasonal ingredients
    assert_equal 1, OccasionReferent.count
    assert_equal 22, Tag.where(tagtype: 4).count
    assert_equal 22, month_tag.referents.first.ingredient_referents.count
  end
end