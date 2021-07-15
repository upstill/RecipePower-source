require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class ThespruceeatsDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
  def setup
    @ingredients = %w{ cauliflower extra\ virgin\ olive\ oil garlic kosher\ salt black\ pepper Parmesan\ cheese } # All ingredients found on the page
    @units =  %w{ medium\ head cup teaspoons teaspoon } # All units
    @conditions = %w{ finely\ grated ground crushed } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
		@grammar_mods = {
			:gm_recipes => { :at_css_match => 'h1' },
			:gm_inglist => {
					:flavor => :unordered_list,
					:list_class => 'structured-ingredients__list',
					:line_class => 'structured-ingredients__list-item'
			},
			:rp_title => { :in_css_match => 'h1' },
			:rp_instructions => { :in_css_match => 'div.structured-project__steps ol' }
		}
		@trimmers = ["ul.tag-nav__list", "ul.social-nav__list", "div.figure__media", "div.aggregate-star-rating", "figure", "div.section-header", "div.nutrition-info", "div.decision-block__feedback", "div.article-header__media", "div.mntl-bio-tooltip__bottom", "div.mntl-bio-tooltip__top", "div.article-updated-date", "div.feedback-block", "div.inline-block", "div.inline-video", "div.featured-link", "div.sources"]
		@selector = "article.article div.l-container"
		@sample_url = 'https://www.thespruceeats.com/roasted-cauliflower-with-parmesan-cheese-3052530'
		@sample_title = 'Parmesan-Roasted Cauliflower'

    #@grammar_mods = {
    # :gm_recipes => { at_css_match: 'h1' },
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
		html =<<EOF
<ul class="structured-ingredients__list text-passage">
<li class="structured-ingredients__list-item">
<p><span data-ingredient-quantity="true">1 </span><span data-ingredient-unit="true">medium</span><span data-ingredient-name="true"> head of&nbsp;cauliflower, </span> cut into bite-size florets</p>
</li>
<li class="structured-ingredients__list-item">
<p><span data-ingredient-quantity="true">1/4</span> <span data-ingredient-unit="true">cup</span> <a href="https://www.thespruceeats.com/types-of-olive-oil-virgin-extra-virgin-and-refined-3054061" data-component="link" data-source="inlineLink" data-type="internalLink" data-ordinal="1"><span data-ingredient-name="true">extra virgin olive oil</span></a></p>
</li>
<li class="structured-ingredients__list-item">
<p><span data-ingredient-quantity="true">2</span> <span data-ingredient-unit="true">teaspoons</span> crushed <span data-ingredient-name="true">garlic</span></p>
</li>
<li class="structured-ingredients__list-item">
<p><span data-ingredient-quantity="true">1</span> <span data-ingredient-unit="true">teaspoon</span> <span data-ingredient-name="true">kosher salt</span></p>
</li>
<li class="structured-ingredients__list-item">
<p><span data-ingredient-quantity="true">1/2</span> <span data-ingredient-unit="true">teaspoon</span> <span data-ingredient-name="true">ground black pepper</span></p>
</li>
<li class="structured-ingredients__list-item">
<p><span data-ingredient-quantity="true">1/2</span> <span data-ingredient-unit="true">cup</span> finely <span data-ingredient-name="true">grated </span><a href="https://www.thespruceeats.com/parmesan-cheese-substitutes-591333" data-component="link" data-source="inlineLink" data-type="internalLink" data-ordinal="1"><span data-ingredient-name="true">Parmesan cheese</span></a></p>
</li>
</ul>
EOF
    # html = '<li class="ingredient-group"><strong>Crust</strong><ul class="ingredients"><li class="ingredient" itemprop="ingredients">1 1/2 cups all purpose flour</li><li class="ingredient" itemprop="ingredients">3 tablespoons sugar</li><li class="ingredient" itemprop="ingredients">1/4 teaspoon salt</li><li class="ingredient" itemprop="ingredients">1/2 cup (1 stick) chilled unsalted butter, cut into 1/2-inch cubes</li><li class="ingredient" itemprop="ingredients">2 tablespoons chilled whipping cream</li><li class="ingredient" itemprop="ingredients">1 large egg yolk</li></ul></li>'
    pt_apply :rp_inglist, html: html, ingredients: @ingredients, units: @units, conditions: @conditions
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