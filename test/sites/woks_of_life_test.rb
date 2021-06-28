require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

class WoksOflifeTest < ActiveSupport::TestCase
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
    @grammar_mods = {
        rp_title: { in_css_match: 'h2'},
        rp_recipe: { in_css_match: 'div.wprm-recipe-the-woks-of-life' }
    
    }
    @selector = 'div.wprm-recipe-the-woks-of-life'
    @trimmers = [ 'div.wprm-entry-footer', 'div.social', 'div.wprm-container-float-right' ]
    @page = 'https://thewoksoflife.com/simple-spicy-pan-fried-noodles/'
    super
  end

  test 'recipe loaded correctly' do
    pt_apply url: 'https://thewoksoflife.com/simple-spicy-pan-fried-noodles/'
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal 'Simple, Spicy Pan-fried Noodles', recipe.title
  end

end
