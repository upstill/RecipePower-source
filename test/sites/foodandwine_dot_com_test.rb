require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class FoodandwineDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = [ 'plain Greek yogurt', 'lime zest', 'fresh lime juice', 'Kosher salt', 'medium-grade bulgur', 'baking soda',
                     'Tuscan kale leaves', 'shallot', 'garlic clove', 'flat-leaf parsley', 'European cucumber',
                     'dried sour cherries', 'mint', 'extra-virgin olive oil', 'fresh lemon juice', 'Freshly ground pepper' ] # All ingredients found on the page
    @units = %w{ tablespoons cup small large teaspoon tablespoon } # All units
    @conditions = %w{ finely\ grated chopped  } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
    @grammar_mods = {
        :gm_inglist => {
            :flavor => :unordered_list,
            :list_class => 'ingredients-section',
            :line_class => 'ingredients-item'
        },
        :rp_title => {:in_css_match => 'h1.headline'},
        :rp_instructions => {:in_css_match => nil}
    }
    @trimmers = ["div.articleContainer__rail", "div.docked-sharebar", "div.lazy-image"]
    @selector = "div.content"
    @sample_url = 'http://www.foodandwine.com/recipes/stuffed-kale-with-bulgur-tabbouleh-and-lime-yogurt-dip'
    @sample_title = 'Stuffed Kale with Bulgur Tabbouleh and Lime Yogurt Dip'

    #@grammar_mods = {
    # :gm_inglist =>
      #:inline  # Multiple ingredients in a single line, comma-separated
      #:unordered_list  # <li> within <ul>
      #{ :flavor => :unordered_list,
      #  :list_selector => , OR :list_class => ,
      #  :line_selector => , OR  :line_class
      #}
      #:paragraph
      #{ :flavor => :paragraph, :selector => 'paragraph_selector' OR :css_class => 'paragraph class' }
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
    html = '1 tablespoon fresh lime juice'
    pt_apply :rp_ingspec, html: html, ingredients: 'fresh lime juice', units: 'tablespoon'
    html =<<EOF
  <li data-tracking-zone="recipe-interaction" data-id="649c227d48ddde381f5de8e37fd36b56" class="ingredients-item">
    <label for="recipe-ingredients-label-483472-0-2" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 tablespoon fresh lime juice" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-2" class="checkbox-list-input">
      <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 tablespoon fresh lime juice </span></span></label>
    <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div>
  </li>
EOF
    pt_apply :rp_ingline, html: html, ingredients: 'fresh lime juice', units: 'tablespoon'
    html = '<ul data-tracking-label="ingredients section" class="ingredients-section"><li data-tracking-zone="recipe-interaction" data-id="2d951ab868bc561aee095a4ce0a44c65" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-0" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 cup plain Greek yogurt" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-0" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 cup plain Greek yogurt </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="e52347503921e4bc0ba2a7137b0dc69a" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-1" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="2 tablespoons finely grated lime zest" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-1" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  2 tablespoons finely grated lime zest </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="649c227d48ddde381f5de8e37fd36b56" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-2" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 tablespoon fresh lime juice" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-2" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 tablespoon fresh lime juice </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="9c3855e50d9025066382f21924b6b81a" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-3" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="Kosher salt" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-3" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  Kosher salt </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="f3328ad41052ffc94bb4e9699bf62d37" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-4" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1/2 cup medium-grade bulgur" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-4" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1/2 cup medium-grade bulgur </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="d77103ef2a877ae3b16dd4f9e2c5df4c" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-5" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 teaspoon baking soda" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-5" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 teaspoon baking soda </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="6c0383346063444a7d28113dae83dcae" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-6" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="16 large Tuscan kale leaves (1 pound)" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-6" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  16 large Tuscan kale leaves (1 pound) </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="aa775bd9691c1c0ba7bccdcb3ed3a219" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-7" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 small shallot, minced" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-7" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 small shallot, minced </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="0e0d9d7d413c5871db5d8bcd0478ad1d" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-8" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 garlic clove, minced" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-8" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 garlic clove, minced </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="dde48917bce458d80616e7c92937452c" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-9" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1 cup chopped flat-leaf parsley" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-9" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1 cup chopped flat-leaf parsley </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="e26de31e00246dacafc334ce057d5c1d" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-10" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1/2 European cucumber&amp;mdash;peeled, halved, seeded and finely chopped" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-10" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1/2 European cucumber—peeled, halved, seeded and finely chopped </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="fc1c16e90a938b7c7734f4853df83e3a" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-11" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1/2 cup dried sour cherries, chopped" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-11" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1/2 cup dried sour cherries, chopped </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="0fa654818f777ac5b7ab5b61ab338136" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-12" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1/4 cup chopped mint" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-12" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1/4 cup chopped mint </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li> <li data-tracking-zone="recipe-interaction" data-id="5a9cd73f32e3255026d54d29f3a7c33a" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-13" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="1/4 cup extra-virgin olive oil" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-13" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  1/4 cup extra-virgin olive oil </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><div data-v-702ba866="" class="cal-on-sale-tag-container"><div data-v-702ba866="" tabindex="0" class="cal-on-sale-tag"><img data-v-702ba866="" src="https://moprd-cdnservice-uw1.azureedge.net/images/local-offers-tag.png"></div></div></div></li> <li data-tracking-zone="recipe-interaction" data-id="bbe57a37d0555b2c52e98703dd6a3e64" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-14" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="2 tablespoons fresh lemon juice" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-14" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  2 tablespoons fresh lemon juice </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><div data-v-702ba866="" class="cal-on-sale-tag-container"><div data-v-702ba866="" tabindex="0" class="cal-on-sale-tag"><img data-v-702ba866="" src="https://moprd-cdnservice-uw1.azureedge.net/images/local-offers-tag.png"></div></div></div></li> <li data-tracking-zone="recipe-interaction" data-id="e78dc5c64f914744b7f6936a0620e2d4" class="ingredients-item"><label for="recipe-ingredients-label-483472-0-15" class="checkbox-list"><input data-tracking-label="ingredient clicked" data-quantity="" data-init-quantity="" data-unit="" data-ingredient="Freshly ground pepper" data-unit_family="" type="checkbox" value=" " id="recipe-ingredients-label-483472-0-15" class="checkbox-list-input"> <span class="checkbox-list-checkmark" style="display: inline-block;"><span class="ingredients-item-name">  Freshly ground pepper </span></span></label> <div data-v-702ba866="" aria-hidden="true" style="display: inline; cursor: pointer; background: white;"><!----></div></li></ul>'
    pt_apply :rp_inglist, html: html, ingredients: @ingredients, units: @units, conditions: @conditions
    assert_good
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
