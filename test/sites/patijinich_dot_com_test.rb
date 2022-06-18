require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class PatijinichDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @grammar_mods = {
        :rp_title => {
            :in_css_match => "h1,h2,h3"
        },
        :gm_bundles => :wordpress,
    }

    @trimmers = ["div.single-recipe__header__right__left", "div.single-recipe__header__right__right"]
    @selector = "div.wprm-recipe"

    @ingredients = %w{ olive\ oil white\ onion raw\ pine\ nuts garlic\ clove ripe\ tomatoes
    ancho\ chiles freshly\ squeezed\ orange\ juice vegetable\ broth chicken\ broth kosher\ salt sea\ salt
    brown\ sugar white\ button\ mushrooms baby\ bella\ mushrooms unsalted\ butter asparagus fresh\ thyme
    orange\ zest corn\ tortillas goat\ cheese chives pine\ nuts freshly\ ground\ black\ pepper } # All ingredients found on the page
    @units =  %w{ tablespoon tablespoons teaspoon teaspoons ounces cup cups pound } # All units
    @conditions = %w{ chopped packed grated  } # All conditions
    @sample_url = 'https://patijinich.com/asparagus-mushroom-and-goat-cheese-enchiladas-with-pine-nut-mole/'
    @sample_title = 'Asparagus Mushroom & Goat Cheese Enchiladas with Pine Nut Mole Sauce'

=begin
    @ingredients = %w{  sweet\ potatoes lard vegetable\ shortening kosher\ salt coarse\ sea\ salt
      baking\ powder brown\ sugar corn\ masa\ flour masa\ harina chicken\ broth vegetable\ broth
      dried\ corn\ husks refried\ beans Mexican\ crema queso\ fresco
    }
    @units = %w{ pounds cup teaspoon tablespoon cups }
    @conditions = %w{ }
    # Grammar mods, css_selector and trimmers that apply to recipes

    @sample_url = 'https://patijinich.com/sweet-potato-and-black-bean-tamales/'
    @sample_title = 'Sweet Potato and Black Bean Tamales'
=end

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

  test 'ingredient line' do
    pt_apply :rp_presteps, string: 'grated', :conditions => 'grated'

    string = '1 tablespoon grated orange zest'
    pt_apply :rp_ingline, string: string, :ingredients => 'orange zest', :units => 'tablespoon', :conditions => 'grated'
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