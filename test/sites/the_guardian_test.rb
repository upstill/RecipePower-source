require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This file is a template for tests to develop site-specific scraping parameters. There are three:
# -- content selector: a CSS selector to pull the recipe content from a page
# -- trimmers: a set of CSS selectors for elements that should be removed from the content
# -- modifications to the Parser grammar for parsing either
#      1) a recipe page into multiple recipes, or
#      2) a single recipe into title, ingredient list, and other information
class TheGuardianTest < ActiveSupport::TestCase
  include PTInterface

  # The setup function defines
  # -- tags of various types that will be used in the recipe's page, defined in the test database
  # -- @lex: a Lexaur generated from those tags
  # -- @grammar_mods: a Hash defining modifications to the default Parser grammar. This will be bound to
  #     the associated Site, both in testing and (by hand) in the production database
  # -- @selector: a CSS selector for the smallest element on the page containing the entire recipe. This
  #     will be the basis of a Finder for Content, used when the PageRef gets gleaned
  # -- @trimmers: an array of CSS selectors; elements that answer to those selectors will be removed from the content
  # -- @page: the page used for the test
  def setup
    super
    # Define all the tags we'll need for the site. (These will need to be extant on RecipePower itself)
    @ingredient_tags = %w{ lemon\ zest salt sea\ salt sourdough\ bread pine\ nuts anchovy\ fillets flaked\ sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves
    cooking\ chorizo eggs asparagus\ spears avocados olive\ oil lemon\ juice Greek-style\ yoghurt parsley\ leaves
    sunflower\ seeds pumpkin\ seeds maple\ syrup Salt kale white-wine\ vinegar wholegrain\ mustard asparagus frozen\ shelled\ edamame tarragon\ leaves dill }
    @unit_tags = %w{ g tbsp tsp large }
    @condition_tags = %w{ crustless ripe }
    @grammar_mods = {
        :rp_recipelist => { match: { at_css_match: 'h2' } },
        :rp_recipe => { at_css_match: 'h2' },
        :rp_title => { in_css_match: 'h2' },
        :gm_inglist => :paragraph
    }
    @selector = 'div.dcr-hujbr5'
    # These selectors remove elements from the page
    @trimmers = ["div.meta__extras", "div.js-ad-slot", "figure[itemprop=\"associatedMedia image\"]", "div.submeta"]
    @page = 'https://www.theguardian.com/lifeandstyle/2018/may/05/yotam-ottolenghi-asparagus-recipes'
    super
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
    pt_apply :recipe,
             url: @page,
             ingredients: %w{ lemon\ zest lemon\ juice sourdough\ bread anchovy\ fillets },
             conditions: %w{ crustless },
             units: %w{ g }
    assert_equal "Kale and grilled asparagus salad", recipe.title
  end

end
