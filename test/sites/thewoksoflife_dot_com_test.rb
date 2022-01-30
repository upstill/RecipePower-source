require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class ThewoksoflifeDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = ['fresh Hong Kong Style Pan-Fried Noodles',
                    'soy sauce',
                    'sesame oil',
                    'small capers',
                    'black pepper',
                    'Brussels sprouts',
                    'Dijon mustard',
                    'Lao Gan Ma spicy black bean sauce',
                    'vegetable oil']
    @units = 'pound'
    # Grammar mods, css_selector and trimmers that apply to recipes
    @grammar_mods = {
        :gm_bundles => {:name => :wordpress},
        :rp_title => {:in_css_match => "h2"}
    }
    @trimmers = ["div.wprm-entry-footer", "div.social", "div.wprm-container-float-right", "label.wprm-checkbox-label"]
		@selector = "div.wprm-recipe-the-woks-of-life"
		@sample_url = 'https://thewoksoflife.com/simple-spicy-pan-fried-noodles/'
		@sample_title = 'Simple, Spicy Pan-fried Noodles'
    
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
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page, url: @page
    assert_equal 1, page_ref.recipes.to_a.count
  end

  test 'recipe loaded correctly' do
    pt_apply url: @page
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
