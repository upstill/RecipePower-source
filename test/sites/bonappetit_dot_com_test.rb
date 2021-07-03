require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class BonappetitDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ lime\ zest lime\ juice Dijon\ mustard honey olive\ oil Kosher\ salt
pepper cauliflower\ florets nutritional\ yeast lollo\ rosso\ lettuce romaine frisee Parmesan } # All ingredients found on the page
    @units =  %w{ teaspoon cup cup ounces tablespoon cups } # All units
    @conditions = %w{ finely\ grated fresh 1-inch-wide\ strips torn } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
			:rp_inglist => {
				:in_css_match => "div.recipe__ingredient-list div"
			},
			:rp_ingline => {
				:in_css_match => nil
			},
			:rp_title => {
				:in_css_match => "h1,h2"
			},
			:rp_instructions => {
				:in_css_match => nil
			}
		}
    @selector = "header h1\r\ndiv.recipe__main-content"
    @trimmers = ["ul.social-icons__list"]
		@sample_url = 'http://www.bonappetit.com/recipe/shaved-cauliflower-salad'
		@sample_title = 'Shaved Cauliflower Salad'

    #@grammar_mods = {
    #}
    #@selector = 'div.wprm-recipe-the-woks-of-life'
    #@trimmers = [ 'div.wprm-entry-footer', 'div.social', 'div.wprm-container-float-right' ]
    #@sample_url = the site's :sample attribute
    #@sample_title = the page title of the sample
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
    pt_apply :rp_ingline, html: "1 teaspoon finely grated lime zest", ingredients: 'lime zest', units: 'teaspoon', conditions: 'finely grated'
    pt_apply :rp_ingline, html: "¼ cup fresh lime juice", ingredients: 'lime juice', units: 'cup', conditions: 'fresh'
    pt_apply :rp_ingline, html: "2 cups torn frisee", ingredients: 'frisee', units: 'cups', conditions: 'torn'
    pt_apply :rp_ingline, html: " Kosher salt, freshly ground pepper", ingredients: ['Kosher salt', 'freshly ground pepper']
    pt_apply :rp_ingline, html: "2 cups 1-inch-wide strips lollo rosso lettuce or romaine ", ingredients: ['lollo rosso lettuce', 'romaine'], units: 'cups', conditions: '1-inch-wide strips'
  end

  test 'recipes parsed out correctly' do
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page,
             url: @page,
             ingredients: @ingredients, units: @units, conditions: @conditions
    assert_equal 1, page_ref.recipes.to_a.count
    assert_equal @sample_title, page_ref.recipes.to_a.first.title
  end

  test 'recipe loaded correctly' do
=begin
             ingredients: %w{ lemon\ zest lemon\ juice sourdough\ bread anchovy\ fillets },
             conditions: %w{ crustless },
             units: %w{ g }
=end
    assert_not_empty @page, "No page url specified for ParseTester"
    pt_apply url: @page
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
