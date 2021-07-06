require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class FlybyjingDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ tofu dried\ shiitake\ mushrooms garlic\ cloves ginger Doubanjiang
Sichuan\ Chili\ Crisp chili\ oil fermented\ black\ beans stock bone\ broth Sichuan\ pepper scallions } # All ingredients found on the page
    @units =  %w{ g ounce tsp tbsp cup pinch } # All units
    @conditions = %w{ minced ground roasted } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
      :gm_inglist => :paragraph,
			:rp_title => {
				:in_css_match => "h1,h2"
			},
			:rp_instructions => {
				:in_css_match => "ol"
			}
		}
		@trimmers = ["div.page__teeth", "div.colorful__teeth", "picture"]
		@selector = "article"
		@sample_url = 'https://flybyjing.com/blog/recipe-the-best-vegan-mapo-tofu/'
		@sample_title = 'RECIPE: THE BEST VEGAN MAPO TOFU EVER'

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

  test 'ingredient list' do
    html = '<p><span>1 pinch ground </span><span><a href="https://www.flybyjing.com/collections/frontpage/products/tribute-pepper-erjingtiao-chili-combo?variant=17879532961861" target="_blank">Sichuan pepper</a></span><span> (roasting right before grinding releases maximum flavor)</span><br></p>'
    pt_apply :rp_inglist, html: html, ingredients: 'Sichuan pepper', units: 'pinch', conditions: 'ground'
    assert_good # Run standard tests on the results

    html = '<p><span>300g tofu cut into cubes (I prefer the texture of softer tofu but regular works as well)</span><br></p>'
    pt_apply :rp_inglist, html: html, ingredients: 'tofu'
    assert_good # Run standard tests on the results

    html =<<EOF
<p>
  <span>300g tofu cut into cubes (I prefer the texture of softer tofu but regular works as well)</span><br>
  <span>1 ounce dried shiitake mushrooms (dried is important as it has much more concentrated umami flavor than fresh)</span><br>
  <span>2 garlic cloves, minced</span><br>
  <span>1 tsp minced ginger</span><br>
  <span>2 tbsp </span><span><a href="https://www.flybyjing.com/collections/frontpage/products/premium-3-year-aged-broad-bean-paste" target="_blank">Doubanjiang</a></span><span> (fermented fava (broad) bean paste)</span><br>
  <span>2 tbsp </span><span><a href="https://www.flybyjing.com/collections/frontpage/products/sichuan-chili-crisp?variant=16950355361861" target="_blank">Sichuan Chili Crisp</a></span><br>
  <span>3 tbsp chili oil (*super easy recipe for this below, but you can substitute with regular oil for less heat if you'd like)</span><br>
  <span>1 tbsp </span><span><a href="https://www.amazon.com/Pearl-River-Bridge-Flavor-Preserved/dp/B004E55SDG/ref=sr_1_3?keywords=fermented+black+beans&amp;qid=1583261576&amp;sr=8-3" target="_blank">fermented black beans</a></span><br>
  <span>1/2 cup stock or bone broth (you can also substitute the water used for soaking shiitakes)</span><br>
  <span>1 tsp cornstarch dissolved in 1 tbsp water</span><br>
  <span>1/2 tsp whole </span><span><a href="https://www.flybyjing.com/collections/frontpage/products/tribute-pepper-erjingtiao-chili-combo?variant=17879532961861" target="_blank">Sichuan pepper</a></span><br>
  <span>1 pinch ground </span><span><a href="https://www.flybyjing.com/collections/frontpage/products/tribute-pepper-erjingtiao-chili-combo?variant=17879532961861" target="_blank">Sichuan pepper</a></span><span> (roasting right before grinding releases maximum flavor)</span><br>
  <span>3 scallions, whites cut in 1 inch pieces, greens thinly sliced</span><br><br>
</p>
EOF
    pt_apply :rp_inglist, html: html, ingredients: @ingredients, units: @units-%w{g}, conditions: @conditions - %w{roasted}
    assert_good # Run standard tests on the results
  end

  test 'recipes parsed out correctly' do
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page, url: @page
    assert_good # Run standard tests on the results
    assert_equal 1, page_ref.recipes.to_a.count
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
    pt_apply url: @page
    # The ParseTester applies the setup parameters to the recipe
    assert_good counts: { :rp_ingline => 13 } # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
