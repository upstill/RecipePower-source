require 'test_helper'
require 'page_ref.rb'

class RecipeServicesTest < ActiveSupport::TestCase
  fixtures :recipes

  def setup
    @test_url = 'http://www.realsimple.com/food-recipes/ingredients-guide/shrimp-00000000039364/index.html'
    @rcp1 = Recipe.new
    @rcp1.url = @test_url
    @rcp1.title = 'Some bogus recipe'
    @rcp1.save
    x=2
  end

  test "lookup recipe by url" do
    # table = PageRef.arel_table
    # page_refs_with_alias = PageRef.where(PageRef.url_query test_url)

    assert_not_nil RecipePageRef.fetch(@test_url)
    rec = Recipe.find_by_url @test_url
    assert_equal @rcp1, rec
    assert_not_nil rec.site
  end

  test "lookup recipe with path" do
    rec = Recipe.query_on_path( 'www.realsimple.com/food-recipes').first
    assert_equal @rcp1, rec
  end

end