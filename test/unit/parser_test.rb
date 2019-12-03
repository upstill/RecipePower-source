require 'test_helper'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/seeker.rb'

class ParserTest < ActiveSupport::TestCase
  def setup
    @amounts = [
        '2 cloves',
        '1 1/2 cup',
        '1/4 cup',
        '½ cup',
        '1 head',
        '1 small head'
    ]
    @ingred_specs = [
        '2 cloves garlic',
        '2 garlic cloves',
        'Sea salt',
        '6 tablespoons butter, softened',
        '2 teaspoons Dijon mustard',
        '1/4 cup drained small capers, rinsed',
        'Grated zest of 1 lemon',
        '3 tablespoons chopped marjoram',
        'Black pepper',
        '1 pound Brussels sprouts',
        '1 small head (1/2 pound) white cauliflower',
        '1 small head (1/2 pound) Romanesco (green) cauliflower'
    ]
    @ingred_tags = %w{ 'garlic sea\ salt butter Dijon\ mustard capers marjoram black\ pepper Brussels\ sprouts white\ cauliflower Romanesco\ (green)\ cauliflower'}.
        each { |name| Tag.assert name, :Ingredient }
    @unit_tags = %w{ 'tablespoon teaspoon cup pound small\ head clove }.
        each { |name| Tag.assert name, :Unit }
    @process_tags = %w{ chopped softened rinsed }.
        each { |name| Tag.assert name, :Unit }
    @lex = Lexaur.from_tags
    @ings_list = <<EOF
  <p>#{@ingred_specs.join "<br>\n"}</p>
EOF
    @recipe = <<EOF
<div class="entry-content"> 
  <p><b>Cauliflower and Brussels Sprouts Salad with Mustard-Caper Butter</b><br>
     Adapted from Deborah Madison, via <a href="http://www.latimes.com/features/food/la-fo-cauliflowerrec1jan10,1,2176865.story?coll=la-headlines-food">The Los Angeles Times, 1/10/07</a></p>
   
  <p>Servings: 8 (Deb: Wha?)</p>
   
#{@ings_list}
   
  <p>1. To make the mustard-caper butter, pound the garlic with a half-teaspoon salt in a mortar until smooth. Stir the garlic into the butter with the mustard, capers, lemon zest and marjoram. Season to taste with pepper. (The butter can be made a day ahead and refrigerated. Bring to room temperature before serving.)</p>
   
  <p>2. Trim the base off the Brussels sprouts, then slice them in half or, if large, into quarters. Cut the cauliflower into bite-sized pieces.</p>
   
  <p>3. Bring a large pot of water to a boil and add salt. Add the Brussels sprouts and cook for 3 minutes. Then add the other vegetables and continue to cook until tender, about 5 minutes. Drain, shake off any excess water, then toss with the mustard-caper butter. Taste for salt, season with pepper and toss again.</p>
   </div>
EOF
  end

  test 'parse amount specs' do
    @amounts.each do |amtstr|
      puts "Parsing '#{amtstr}'"
      nokoscan = NokoScanner.from_string amtstr
      is = AmountSeeker.match nokoscan, @lex
      assert_not_nil is, "#{amtstr} doesn't parse"
    end
  end

  test 'parse individual ingredient' do
    ingstr = 'Dijon mustard'
    nokoscan = NokoScanner.from_string ingstr
    is = TagSeeker.seek nokoscan, lexaur: @lex, types: 4
    assert_not_nil is, "#{ingstr} doesn't parse"
  end

  test 'parse alt ingredient' do
    ingstr = 'small capers, black pepper or Brussels sprouts'
    nokoscan = NokoScanner.from_string ingstr
    is = IngredientsSeeker.seek nokoscan, lexaur: @lex, types: 4
    assert_not_nil is, "#{ingstr} doesn't parse"
    assert_equal 3, is.tag_seekers.count, "Didn't find 3 ingredients in #{ingstr}"
  end

  test 'parse individual ingredient specs' do
    @ingred_specs.each do |ingspec|
      puts "Parsing '#{ingspec}'"
      nokoscan = NokoScanner.from_string ingspec
      is = IngredientSpecSeeker.match nokoscan, @lex
      assert_not_nil is, "#{ingspec} doesn't parse"
    end
  end

  test 'parse a whole ingredient list' do
    nokoscan = NokoScanner.from_string @ings_list
  end

  test 'find the ingredient list embedded in a recipe' do
    nokoscan = NokoScanner.from_string @recipe
    il = IngredientListSeeker nokoscan
    assert_not_nil il
  end

end