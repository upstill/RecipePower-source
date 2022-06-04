require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class SeriouseatsDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ Salt Cooking\ oil Sichuan\ chile\ bean\ paste
      garlic ginger stock water superfine\ sugar Chinese\ light\ soy\ sauce potato\ starch
      Chinkiang\ vinegar scallion\ greens water 
     } # All ingredients found on the page
    @units =  %w{ g pound ounces tablespoons tablespoon teaspoons teaspoon ml } # All units
    @conditions = %w{ finely\ chopped hot thinly\ sliced cold } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
      :gm_inglist => {
          :flavor => :unordered_list,
          :list_class => 'structured-ingredients__list',
          :line_class => 'structured-ingredients__list-item'
      },
			:rp_title => {
				:in_css_match => "h1.heading__title"
			}
		}
		@trimmers = ["div.nav-share", "div.pubmod-date", "figure", "div.author-byline"]
		@selector = "div.article__container"
    @sample_url = "http://www.seriouseats.com/creamy-braised-pork-and-bean-stew-cinnamon-fennel-and-onion-5217276"
		@sample_title = 'Creamy Braised Pork and Bean Stew With Cinnamon, Fennel, and Onion'

    @sample_url = 'http://www.seriouseats.com/recipes/2010/04/fish-fragrant-eggplant-recipe-fuchsia-dunlop.html'
    @sample_title = 'Fish-Fragrant Eggplants (Sichuan Braised Eggplant With Garlic, Ginger, and Chiles) Recipe'

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

  test 'ingredient line' do
    string = "(1.4kg)"
    pt_apply :rp_altamt, string: string, units: %w{ kg }
    string = "3 pounds (1.4kg) boneless pork butt"
    pt_apply :rp_ingline, string: string, ingredients: %w{ boneless\ pork\ butt }, units: %w{ pounds kg }
  end

  test 'ingredient list' do

    html = '<li class="structured-ingredients__list-item"> 1 pound 5 ounces (600g) eggplants (1–2 large) </li>'
    pt_apply :rp_ingline, html: html, ingredients: 'eggplants', units: %w{ pound ounces }

    html = '<li class="structured-ingredients__list-item"> 10 tablespoons (150ml) hot stock or water </li>'
    pt_apply :rp_ingline, html: html, ingredients: %w{ stock water }, units: %w{ tablespoons }, conditions: 'hot'

    html = '1 pound 5 ounces (600g)'
    pt_apply :rp_amt, html: html, units: %w{ pound ounces }

    html =<<EOF
<ul id="ingredient-list_1-0" class="comp structured-ingredients__list simple-list simple-list--circle ">
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
1 pound 5 ounces (600g) eggplants (1–2 large)
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
Salt
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
Cooking oil, for deep-frying
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
1 1/2 tablespoons Sichuan chile bean paste (see note)
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
1 1/2 tablespoons finely chopped garlic
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
1 tablespoon finely chopped ginger
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
10 tablespoons (150ml) hot stock or water
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
4 teaspoons superfine sugar
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
1 teaspoon Chinese light soy sauce
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
3/4 teaspoon potato starch, mixed with 1 tablespoon cold water
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
1 tablespoon Chinkiang vinegar (see note)
</li>
<li class="structured-ingredients__list-item js-checkbox-trigger ingredient text-passage">
6 tablespoons thinly sliced scallion greens
</li>
</ul>
EOF
    pt_apply :rp_inglist, html: html, ingredients: @ingredients, conditions: @conditions
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
    assert_not_empty @page, "No page url specified for ParseTester"
    pt_apply url: @page, ingredients: @ingredients, units: @units, conditions: @conditions
    # The ParseTester applies the setup parameters to the recipe
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
