require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class NutritionactionDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ extra-virgin\ olive\ oil pine\ nuts garlic lemon\ zest
lemon\ juice flat-leaf\ parsley cauliflower\ florets kosher\ salt } # All ingredients found on the page
    @units =  %w{ tsp. cup Tbs. lb. clove sprigs } # All units
    @conditions = %w{ fresh freshly\ ground thinly\ sliced  } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
      :gm_inglist => :paragraph,
			:rp_title => {
				:in_css_match => "h3"
			}
		}
		@sample_url = 'https://www.nutritionaction.com/daily/healthy-recipes/three-vegetable-sides-perfect-for-the-holiday-season/'
		@sample_title = 'Cauliflower with Lemon-Pine Nut Dressing'

    @grammar_mods = {
     :gm_inglist => :paragraph
      #:inline  # Multiple ingredients in a single line, comma-separated
      #:unordered_list  # <li> within <ul>
      #{ :flavor => :unordered_list,
      #  :list_selector => , OR :list_class => ,
      #  :line_selector => , OR  :line_class
      #}
      #:paragraph
    }
    @selector = 'div.entry-content'
    @trimmers = [ 'div.wprm-entry-footer', 'div.social', 'div.wprm-container-float-right' ]
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

  test 'ingredient list' do
    # html = '<li class="ingredient-group"><strong>Crust</strong><ul class="ingredients"><li class="ingredient" itemprop="ingredients">1 1/2 cups all purpose flour</li><li class="ingredient" itemprop="ingredients">3 tablespoons sugar</li><li class="ingredient" itemprop="ingredients">1/4 teaspoon salt</li><li class="ingredient" itemprop="ingredients">1/2 cup (1 stick) chilled unsalted butter, cut into 1/2-inch cubes</li><li class="ingredient" itemprop="ingredients">2 tablespoons chilled whipping cream</li><li class="ingredient" itemprop="ingredients">1 large egg yolk</li></ul></li>'
    # pt_apply :rp_inglist, html: html, ingredients: @ingredients, units: @units, conditions: @conditions
  end

  test 'recipes parsed out correctly' do
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page, url: @page
    assert_good counts: { :rp_recipe => 3 }
    assert_equal @sample_title, page_ref.recipes.to_a.first.title
    assert_equal [
                     "Cauliflower with Lemon-Pine Nut Dressing",
                     "Broccoli with Balsamic Dressing",
                     "Brussels Sprouts with Orange Dressing"
                 ].sort, page_ref.recipes.map(&:title).sort
  end

  test 'recipe loaded correctly' do
    assert_not_empty @page, "No page url specified for ParseTester"
    pt_apply url: @page, ingredients: @ingredients, units: @units, conditions: @conditions
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
