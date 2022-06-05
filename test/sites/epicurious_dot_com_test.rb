require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class EpicuriousDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ all\ purpose\ flour sugar salt unsalted\ butter whipping\ cream
egg\ yolk natural\ unsalted\ pistachios slivered\ almonds sugar egg vanilla\ extract almond\ extract
apricots apricot\ jam water pistachios
} # All ingredients found on the page
    @units =  %w{ teaspoons cup large stick large tablespoons teaspoon tablespoons } # All units
    @conditions = %w{ chopped chilled shelled } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
=begin
			:gm_inglist => {
					:flavor => :unordered_list,
					:list_class => 'ingredient-group',
					:line_class => 'ingredient'
		},
=end
			:rp_title => {
				:in_css_match => "h1"
			},
			:rp_inglist => {
					:in_css_match => 'div.gPuEKn'
			},
			:rp_ingline => {
					:in_css_match => 'div.eftAc',
					:match_all => true
			},
			:rp_instructions => {
				:in_css_match => "div.instructions ol"
			}
		}
		@trimmers = ["div.mediavoice-native-ad", "div.additional-info"]
		@selector = "h1
div.body
div[data-testid=IngredientList]
div[data-testid=InstructionsWrapper]"
		@sample_url = 'http://www.epicurious.com/recipes/food/views/apricot-tart-with-pistachio-almond-frangipane-106662'
		@sample_title = 'Apricot Tart with Pistachio-Almond Frangipane'
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
		html = '<div class="ingredient-group"><strong>Crust</strong><div class="List-gPuEKn"><div class="Description-eftAc" itemprop="ingredients">1 1/2 cups all purpose flour</div><div class="Description-eftAc" itemprop="ingredients">3 tablespoons sugar</div><div class="Description-eftAc" itemprop="ingredients">1/4 teaspoon salt</div><div class="Description-eftAc" itemprop="ingredients">1/2 cup (1 stick) chilled unsalted butter, cut into 1/2-inch cubes</div><div class="Description-eftAc" itemprop="ingredients">2 tablespoons chilled whipping cream</div><div class="Description-eftAc" itemprop="ingredients">1 large egg yolk</div></div></div>'
		pt_apply :rp_inglist, html: html

		html = '<div class="ingredient-group"><strong>Filling</strong><div class="List-gPuEKn"><div class="Description-eftAc" itemprop="ingredients">1/2 cup shelled natural unsalted pistachios (about 2 ounces)</div><div class="Description-eftAc" itemprop="ingredients">1/2 cup slivered almonds (about 2 ounces)</div><div class="Description-eftAc" itemprop="ingredients">1/2 cup sugar</div><div class="Description-eftAc" itemprop="ingredients">1/2 cup (1 stick) chilled unsalted butter, cut into 1/2-inch cubes</div><div class="Description-eftAc" itemprop="ingredients">1 large egg</div><div class="Description-eftAc" itemprop="ingredients">1 teaspoon vanilla extract</div><div class="Description-eftAc" itemprop="ingredients">1/2 teaspoon almond extract</div></div></div>'
		pt_apply :rp_inglist, html: html

		html = '<div class="ingredient-group"><div class="List-gPuEKn"><div class="Description-eftAc" itemprop="ingredients">9 large apricots, halved, pitted</div></div></div>'
		pt_apply :rp_inglist, html: html

		html = '<div class="ingredient-group"><strong>Glaze</strong><div class="List-gPuEKn"><div class="Description-eftAc" itemprop="ingredients">1/3 cup apricot jam</div><div class="Description-eftAc" itemprop="ingredients">2 teaspoons water</div><div class="Description-eftAc" itemprop="ingredients">Chopped pistachios</div></div></div>'
		pt_apply :rp_inglist, html: html
	end

  test 'recipes parsed out correctly' do
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page, url: @page
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
