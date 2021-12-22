require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class FantasticfungiDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ sage\ leaves garlic\ clove fresh\ rosemary white\ beans
Extra\ Virgin\ Olive\ Oil autumn\ mushrooms virgin\ coconut\ oil sherry\ vinegar
Salt pepper } # All ingredients found on the page
    @units = %w{ medium-sized small Tablespoons cups teaspoon inch section ounce can  } # All units
    @conditions = %w{ diced  } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
    @grammar_mods = {
        :gm_inglist => { :flavor => :unordered_list },
        :rp_title => { :in_css_match => "h1,h2" },
        :rp_instructions => { :in_css_match => "div.instructions" }
    }
    @trimmers = ["div.article-gallery", "h6", "a.btn-large"]
    @selector = "div.main-content"
    @sample_url = 'https://fantasticfungi.com/cookbook-recipes/white-bean-and-autumn-mushroom-dip/'
    @sample_title = 'White Bean and Autumn Mushroom Dip'

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

  test 'ingredient spec' do
    html = '15-ounce can of white beans'
    pt_apply :rp_ingspec, html: html, ingredients: %w{ white\ beans }, units: [ 'ounce', 'can' ]

    html = '15 ounce can of white beans'
    pt_apply :rp_ingspec, html: html, ingredients: %w{ white\ beans }, units: [ 'ounce', 'can' ]

    html = '6-inch section of fresh rosemary'
    pt_apply :rp_ingspec, html: html, ingredients: %w{ fresh\ rosemary }, units: [ 'inch', 'section' ]
  end

  test 'ingredient list' do
    # TODO: Pass this test (Needles from one, 6-inch section of fresh rosemary)
    # html = '<li class="list"><p>Needles from one, 6-inch section of fresh rosemary </p></li>'
    html = '<li class="list"><p>6-inch section of fresh rosemary </p></li>'
    pt_apply :rp_ingline, html: html, ingredients: %w{ fresh\ rosemary }, units: [ 'inch', 'section' ]
    html =<<EOF
<div class="ingredients">
  <ul>
    <li class="list"><p>One, 15 ounce can of white beans, such as Cannellini or Navy </p></li>
    <li class="list"><p>6 medium-sized sage leaves </p></li>
    <li class="list"><p>Needles from one, 6-inch section of fresh rosemary </p></li>
    <li class="list"><p>One small garlic clove </p></li>
    <li class="list"><p>3 Tablespoons Extra Virgin Olive Oil, divided </p></li>
    <li class="list"><p>1 1/2 cups diced autumn mushrooms, such as blewits and maitake </p></li>
    <li class="list"><p>1 teaspoon virgin coconut oil </p></li>
    <li class="list"><p>1 teaspoon sherry (or other wine) vinegar </p></li>
    <li class="list"><p>Salt and pepper to taste</p></li>
   </ul>
</div>
EOF
    handicapped_ingredients = @ingredients - %w{ fresh\ rosemary white\ beans }
    handicapped_units = @units - %w{ inch section ounce can }
    pt_apply :rp_inglist, html: html, ingredients: handicapped_ingredients, units: handicapped_units, conditions: @conditions
    assert_good counts: { :rp_ingspec => 7 } # Run standard tests on the results
  end

  test 'recipes parsed out correctly' do
    # Test that the recipe_page parses out individual recipes (usually only one)
    pt_apply :recipe_page, url: @page
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
    assert_not_empty @page, "No page url specified for ParseTester"
    pt_apply url: @page, ingredients: @ingredients, units: @units, conditions: @conditions
    # The ParseTester applies the setup parameters to the recipe
    assert_good counts: { :rp_ingline => 9 } # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
