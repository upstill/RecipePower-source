require 'test_helper'
require 'parse_tester'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# This is the template for parse testers on individual sites
class EverydayannieDotComTest < ActiveSupport::TestCase
  include PTInterface

  # Set up the parser, trimmers, selectors for the woks_of_life site
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
    @conditions = %w{ boneless } # All conditions
    # Grammar mods, css_selector and trimmers that apply to recipes
    @grammar_mods = {
        :rp_title => {:in_css_match => "h1,h2"},
        :rp_instructions => {:in_css_match => nil},
        :gm_inglist => {
            :flavor => :paragraph,
            :selector => 'div.ingredient-text p'
        }
}
@trimmers = ["div.post-cat", "a.comments-number", "div.step-number"]
@selector = "div.post-header
div.recipe-bar
div#ingredients
div#directions ul
"
    @sample_url = 'http://everydayannie.com/2013/07/31/ginger-garlic-salmon-with-cabbage-salad/'
    @sample_title = 'Ginger Garlic Salmon with Cabbage Salad'
    super
  end

  test 'mapping in grammar mods' do
    # Apply tests to the grammar resulting from the grammar_mods here
    assert_equal @parse_tester.grammar_mods[:gm_inglist][:paragraph_selector], grammar[:rp_inglist][:in_css_match]
    assert_nil grammar[:rp_ingline][:in_css_match]
    assert grammar[:rp_ingline][:inline]
  end

  test 'juice of half a lime' do
    pt_apply :rp_ingline, string: 'Juice of ½ lime'
    pt_apply :rp_ingline, string: 'Juice of ½ a lime'
  end

  test 'ingredient list' do
    # Simplified ingredient list
    html =<<EOF
some irrelevant HTML
<div class="ingredient-text text">
								<p><em>For the dressing:&nbsp;</em><br>
¼ cup olive oil<br>
1 tsp. sesame oil<br>
</p></div>
EOF
    remainder = "Following irrelevant html"
    pt_apply :rp_inglist, html: html+remainder, remainder: remainder

    # Slightly less simple ingredient list
    html =<<EOF
some irrelevant HTML
<div class="ingredient-text text">
								<p><em>For the dressing:&nbsp;</em><br>
Juice of&nbsp;½ a lime<br>
¼ cup olive oil<br>
1 tsp. sesame oil<br>
</p></div>
EOF
    pt_apply :rp_inglist, html: html+remainder, remainder: remainder

    html =<<EOF
some irrelevant HTML
<div class="ingredient-text text">
								<p><em>For the dressing:&nbsp;</em><br>
Juice of&nbsp;½ a lime<br>
¼ cup olive oil<br>
1 tsp. sesame oil<br>
3 tbsp. reduced-sodium soy sauce<br>
2 tbsp. honey (or brown sugar)<br>
2 tbsp. fresh ginger, peeled and finely minced<br>
1 clove garlic, minced<br>
1 jalapeño, seeded and minced<br>
1/3 cup fresh cilantro, minced<br>
Salt and pepper, to taste</p>
<p><em>For the salad:</em><br>
1 small-medium head green cabbage, thinly sliced<br>
3 green onions, thinly sliced<br>
1 red bell pepper, seeded and thinly sliced<br>
2 handfuls baby spinach leaves (about 1½-2 cups), roughly chopped<br>
1 carrot, peeled and grated/shredded</p>
<p><em>For the salmon:<br>
</em>1½ lbs. boneless salmon fillets<br>
Juice of&nbsp;½ a lime<br>
2 tbsp. reduced-sodium soy sauce<br>
2 cloves garlic, minced<br>
2 inch knob of ginger, peeled and thinly sliced<br>
Sriracha, to taste<br>
Coarse salt and pepper, to taste</p><div id="AdThrive_Content_2_desktop" class="adthrive-ad adthrive-content adthrive-content-1" data-google-query-id="CMTovbv6uvECFT4B-QAdU38NOw"><div id="google_ads_iframe_/18190176/AdThrive_Content_2/540753cf3467ce8320843965_0__container__" style="border: 0pt none;"><iframe id="google_ads_iframe_/18190176/AdThrive_Content_2/540753cf3467ce8320843965_0" title="3rd party ad content" name="google_ads_iframe_/18190176/AdThrive_Content_2/540753cf3467ce8320843965_0" width="300" height="250" scrolling="no" marginwidth="0" marginheight="0" frameborder="0" data-google-container-id="23" style="border: 0px; vertical-align: bottom;" data-integralas-id-da6a2a28-8590-ee7c-41ab-371b34c459c4="" data-integralas-id-d5ba8816-31d6-6986-5138-81824de134c2="" data-integralas-id-e619f685-f9b2-843b-d789-b4e2ad27779f="" data-load-complete="true"></iframe></div></div>
							</div>
EOF
    pt_apply :rp_recipe_section, html: html

    html =<<EOF
some irrelevant HTML
<div class="ingredient-text text">
								<p><em>For the dressing:&nbsp;</em><br>
Juice of&nbsp;½ a lime<br>
¼ cup olive oil<br>
1 tsp. sesame oil<br>
3 tbsp. reduced-sodium soy sauce<br>
2 tbsp. honey (or brown sugar)<br>
2 tbsp. fresh ginger, peeled and finely minced<br>
1 clove garlic, minced<br>
1 jalapeño, seeded and minced<br>
1/3 cup fresh cilantro, minced<br>
Salt and pepper, to taste</p>
<p><em>For the salad:</em><br>
1 small-medium head green cabbage, thinly sliced<br>
3 green onions, thinly sliced<br>
1 red bell pepper, seeded and thinly sliced<br>
2 handfuls baby spinach leaves (about 1½-2 cups), roughly chopped<br>
1 carrot, peeled and grated/shredded</p>
<p><em>For the salmon:<br>
</em>1½ lbs. boneless salmon fillets<br>
Juice of&nbsp;½ a lime<br>
2 tbsp. reduced-sodium soy sauce<br>
2 cloves garlic, minced<br>
2 inch knob of ginger, peeled and thinly sliced<br>
Sriracha, to taste<br>
Coarse salt and pepper, to taste</p><div id="AdThrive_Content_2_desktop" class="adthrive-ad adthrive-content adthrive-content-1" data-google-query-id="CMTovbv6uvECFT4B-QAdU38NOw"><div id="google_ads_iframe_/18190176/AdThrive_Content_2/540753cf3467ce8320843965_0__container__" style="border: 0pt none;"><iframe id="google_ads_iframe_/18190176/AdThrive_Content_2/540753cf3467ce8320843965_0" title="3rd party ad content" name="google_ads_iframe_/18190176/AdThrive_Content_2/540753cf3467ce8320843965_0" width="300" height="250" scrolling="no" marginwidth="0" marginheight="0" frameborder="0" data-google-container-id="23" style="border: 0px; vertical-align: bottom;" data-integralas-id-da6a2a28-8590-ee7c-41ab-371b34c459c4="" data-integralas-id-d5ba8816-31d6-6986-5138-81824de134c2="" data-integralas-id-e619f685-f9b2-843b-d789-b4e2ad27779f="" data-load-complete="true"></iframe></div></div>
							</div>
EOF
    pt_apply :rp_recipe_section, html: html
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
    assert_good # Run standard tests on the results
    refute recipe.errors.any?

    assert_equal @title, recipe.title
  end

end
