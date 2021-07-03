require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class TheguardianDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    # Define all the tags we'll need for the site. (These will need to be extant on RecipePower itself)
    @ingredient_tags = %w{ lemon\ zest salt sea\ salt sourdough\ bread pine\ nuts anchovy\ fillets flaked\ sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves
    cooking\ chorizo eggs asparagus\ spears avocados olive\ oil lemon\ juice Greek-style\ yoghurt parsley\ leaves
    sunflower\ seeds pumpkin\ seeds maple\ syrup Salt kale white-wine\ vinegar wholegrain\ mustard asparagus frozen\ shelled\ edamame tarragon\ leaves dill }
    @unit_tags = %w{ g tbsp tsp large }
    @condition_tags = %w{ crustless ripe }
    # Grammar mods, css_selector and trimmers that apply to recipes
    @grammar_mods = {
      :gm_recipes => { :at_css_match => 'h2' },
			:rp_title => {
				:in_css_match => "h2"
			},
			:gm_inglist => :paragraph
		}
    @trimmers = ["div.meta__extras", "div.js-ad-slot", "figure[itemprop=\"associatedMedia image\"]", "div.submeta"]
    @selector = "div.dcr-hujbr5"
    @sample_url = 'https://www.theguardian.com/lifeandstyle/2018/may/05/yotam-ottolenghi-asparagus-recipes'
    @sample_title = 'Asparagus with pine nut and sourdough crumbs'
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

  test 'recipes parsed out correctly' do
    pt_apply :recipe_page, url: @page
    assert_equal 3, page_ref.recipes.to_a.count
    assert_equal [
                     "Asparagus with pine nut and sourdough crumbs (pictured above)",
                     "Soft-boiled egg with avocado, chorizo and asparagus",
                     "Kale and grilled asparagus salad"
                 ].sort, page_ref.recipes.map(&:title).sort
    assert_equal "Yotam Ottolenghi’s asparagus recipes", page_ref.title
  end

  test 'parse single recipe' do
    NestedBenchmark.measure "Parsing '#{@title}'" do
      pt_apply :recipe,
               url: @page,
               ingredients: %w{ lemon\ zest lemon\ juice sourdough\ bread anchovy\ fillets },
               conditions: %w{ crustless },
               units: %w{ g }
    end
    assert_equal "Kale and grilled asparagus salad", recipe.title
  end

end
