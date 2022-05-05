require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class CookingDotNytimesDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup # TODO: writes nytimes.com.yml, not cooking.nytimes.com.yml
    @ingredients = %w{ olive\ oil onion garlic\ cloves tomato\ paste cumin kosher\ salt
      black\ pepper chile\ powder cayenne chicken\ broth vegetable\ broth water red\ lentils
      carrot lemon fresh\ cilantro
 } # All ingredients found on the page
    @units =  %w{ tablespoons large tablespoon teaspoon pinch quart cups cup } # All units
    @conditions = %w{ ground } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
			:rp_inglist => {
				:in_css_match => "ul.recipe-ingredients"
			},
			:rp_ingline => {
				:in_css_match => "li"
			},
			:rp_title => {
				:in_css_match => "h1,h2"
			},
			:rp_instructions => {
				:in_css_match => nil
			}
		}
		@trimmers = ["div.nutrition-container", "div.secondary-controls"]
		@selector = "article.recipe-detail-card"
		@sample_url = 'http://cooking.nytimes.com/recipes/1016062-red-lentil-soup-with-lemon'
		@sample_title = 'Red Lentil Soup With Lemon'

    super
  end

  test 'mapping in grammar mods' do
    # Apply tests to the grammar resulting from the grammar_mods here
=begin
    assert_equal @grammar_mods[:gm_inglist][:selector], grammar[:rp_inglist][:match].first[:in_css_match]
    assert_nil grammar[:rp_ingline][:in_css_match]
    assert grammar[:rp_ingline][:inline]
=end
  end

  test 'ingredient lines' do
    html = 'Kosher salt (Diamond Crystal) and black pepper'
    pt_apply :rp_ingspec, html: html, ingredients: %w{ kosher\ salt black\ pepper }
  end

  test 'ingredient list' do
    # html = '<li class="ingredient-group"><strong>Crust</strong><ul class="ingredients"><li class="ingredient" itemprop="ingredients">1 1/2 cups all purpose flour</li><li class="ingredient" itemprop="ingredients">3 tablespoons sugar</li><li class="ingredient" itemprop="ingredients">1/4 teaspoon salt</li><li class="ingredient" itemprop="ingredients">1/2 cup (1 stick) chilled unsalted butter, cut into 1/2-inch cubes</li><li class="ingredient" itemprop="ingredients">2 tablespoons chilled whipping cream</li><li class="ingredient" itemprop="ingredients">1 large egg yolk</li></ul></li>'
    # pt_apply :rp_inglist, html: html, ingredients: @ingredients, units: @units, conditions: @conditions
  end

  test 'recipes parsed out correctly' do
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page, url: @page
    assert_good
    assert_equal @sample_title, page_ref.recipes.to_a.first.title
    # For a page that has multiple recipes, test sorting them out as follows:
=begin
    assert_equal 3, page_ref.recipes.to_a.count
    assert_equal [
                     "Asparagus with pine nut and sourdough crumbs (pictured above)",
                     "Soft-boiled egg with avocado, chorizo and asparagus",
                     "Kale and grilled asparagus salad"
                 ].sort, page_ref.recipes.map(&:title).sort
    assert_equal "Yotam Ottolenghi’s asparagus recipes", page_ref.title
=end
  end

  test 'recipe loaded correctly' do
=begin
             ingredients: %w{ lemon\ zest lemon\ juice sourdough\ bread anchovy\ fillets },
             conditions: %w{ crustless },
             units: %w{ g }
=end
    assert_not_empty @page, "No page url specified for ParseTester"
    pt_apply url: @page, ingredients: @ingredients, units: @units, conditions: @conditions
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
