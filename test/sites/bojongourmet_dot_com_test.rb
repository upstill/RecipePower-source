require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class BojongourmetDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the Bojon Gourmet site
  def setup
    @ingredients = %w{
      lime
      olive\ oil
      sesame\ oil
      reduced-sodium\ soy\ sauce
      honey
      fresh\ ginger
      garlic
      jalapeño
      fresh\ cilantro
      salt
      pepper
      green\ cabbage
      green\ onions
      red\ bell\ pepper
      baby\ spinach\ leaves
      carrot
      salmon\ fillets
      ginger
      sriracha
      coarse\ salt
      pepper
}
    @units =  %w{
      cup
      tsp.
      tbsp.
      clove
      small-medium\ head
      handfuls
      lbs.
      cloves
      inch
      knob
 } # All units
    @conditions = %w{  } # All conditions
    @ingredients = %w{
    water
    granulated\ sugar
    whole\ milk
    heavy\ cream
    coffee\ beans
    ground\ cinnamon
    fine\ sea\ salt
    dark\ muscovado\ sugar
    eggs
    egg\ yolk
    }
    @units = %w{ cup cups teaspoon tablespoons large servings }
    # Grammar mods, css_selector and trimmers that apply to recipes
    @grammar_mods = {
      :gm_bundles => { :name => :wordpress },
      :gm_recipes => { :at_css_match => "h2" },
			:rp_title => {
				:in_css_match => "h2"
			}
    }
    @trimmers = ["div.wprm-recipe-notes-container", "div.wprm-recipe-image", "div.wprm-call-to-action-text-container", "a.wprm-recipe-print", "a.wprm-recipe-pin", "a.wprm-recipe-jump", "div.wprm-recipe-rating", "div.wprm-container-float-right"]
    @selector = "div.wprm-recipe"
    @sample_url = 'http://bojongourmet.com/2015/12/coffee-cinnamon-muscovado-sugar-flans-the-new-sugar-spice-cookbook/?utm_source=feedburner&utm_medium=email&utm_campaign=Feed%3A+BojonGourmet+%28The+Bojon+Gourmet%29'
    @sample_title = 'Coffee, Cinnamon & Muscovado Sugar Flans'
    #@grammar_mods = {
    #}
    #@selector = 'div.wprm-recipe-the-woks-of-life'
    #@trimmers = [ 'div.wprm-entry-footer', 'div.social', 'div.wprm-container-float-right' ]
    super
  end

  test 'ingredient list' do
    # Simplified ingredient list
    html =<<EOF
<ul class="wprm-recipe-ingredients"><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">¼</span> <span class="wprm-recipe-ingredient-unit">cup</span> <span class="wprm-recipe-ingredient-name">water</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-normal">(60 ml) </span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">½</span> <span class="wprm-recipe-ingredient-unit">cup</span> <span class="wprm-recipe-ingredient-name">granulated sugar</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-normal">(100 g) </span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">1 ¾</span> <span class="wprm-recipe-ingredient-unit">cups</span> <span class="wprm-recipe-ingredient-name">whole milk</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-normal">(415 ml) </span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">¼</span> <span class="wprm-recipe-ingredient-unit">cup</span> <span class="wprm-recipe-ingredient-name">heavy cream</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-normal">(60 ml) </span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">¼</span> <span class="wprm-recipe-ingredient-unit">cup</span> <span class="wprm-recipe-ingredient-name">coffee beans, crushed or coarsely ground</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-normal">(20 g) </span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">¼</span> <span class="wprm-recipe-ingredient-unit">teaspoon</span> <span class="wprm-recipe-ingredient-name">ground cinnamon</span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">1/8</span> <span class="wprm-recipe-ingredient-unit">teaspoon</span> <span class="wprm-recipe-ingredient-name">fine sea salt</span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">¼</span> <span class="wprm-recipe-ingredient-unit">cup</span> <span class="wprm-recipe-ingredient-name">+ 2 tablespoons dark muscovado sugar (or organic dark brown sugar)</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-normal">(70 g)</span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">2</span> <span class="wprm-recipe-ingredient-name">large eggs</span></li><li class="wprm-recipe-ingredient" style="list-style-type: disc;"><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-name">large egg yolk</span></li></ul>
EOF
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
    pt_apply url: @page, :expect => [:rp_prep_time, :rp_cook_time, :rp_total_time, :rp_yield ]
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
