require 'test_helper'
require 'scraping/lexaur.rb'
require 'scraping/scanner.rb'

class LexaurTest < ActiveSupport::TestCase
  def setup
    @longstr = <<EOF
<div class="entry-content"> 
  <p><b>Cauliflower and Brussels Sprouts Salad with Mustard-Caper Butter</b><br>
     Adapted from Deborah Madison, via <a href="http://www.latimes.com/features/food/la-fo-cauliflowerrec1jan10,1,2176865.story?coll=la-headlines-food">The Los Angeles Times, 1/10/07</a></p>
   
  <p>Servings: 8 (Deb: Wha?)</p>
   
  <p>2 garlic cloves<br>
     Sea salt<br>
     6 tablespoons butter, softened<br>
     2 teaspoons Dijon mustard<br>
     1/4 cup drained small capers, rinsed<br>
     Grated zest of 1 lemon<br>
     3 tablespoons chopped marjoram<br>
     Black pepper<br>
     1 pound Brussels sprouts<br>
     1 small head (1/2 pound) white cauliflower<br>
     1 small head (1/2 pound) Romanesco (green) cauliflower</p>
   
  <p>1. To make the mustard-caper butter, pound the garlic with a half-teaspoon salt in a mortar until smooth. Stir the garlic into the butter with the mustard, capers, lemon zest and marjoram. Season to taste with pepper. (The butter can be made a day ahead and refrigerated. Bring to room temperature before serving.)</p>
   
  <p>2. Trim the base off the Brussels sprouts, then slice them in half or, if large, into quarters. Cut the cauliflower into bite-sized pieces.</p>
   
  <p>3. Bring a large pot of water to a boil and add salt. Add the Brussels sprouts and cook for 3 minutes. Then add the other vegetables and continue to cook until tender, about 5 minutes. Drain, shake off any excess water, then toss with the mustard-caper butter. Taste for salt, season with pepper and toss again.</p>
   </div>
EOF
    @ings_list = <<EOF
  <p>
     Sea salt<br>
     6 tablespoons butter, softened<br>
     2 teaspoons Dijon mustard<br>
     1/4 cup drained small capers, rinsed<br>
     2 garlic cloves<br>
     Grated zest of 1 lemon<br>
     3 tablespoons chopped marjoram<br>
     Black pepper<br>
     1 pound Brussels sprouts<br>
     1 small head (1/2 pound) white cauliflower<br>
     1 small head (1/2 pound) Romanesco (green) cauliflower</p>
EOF
    @ingred_tags = ['garlic\ clove sea\ salt butter Dijon\ mustard capers marjoram black\ pepper Brussels\ sprouts white\ cauliflower Romanesco\ (green)\ cauliflower'].
        each { |name| Tag.assert name, :Ingredient }
    @unit_tags = %w{ 'tablespoon teaspoon cup pound small\ head clove }.
        each { |name| Tag.assert name, :Unit }
    @process_tags = %w{ chopped softened rinsed }.
        each { |name| Tag.assert name, :Unit }
  end

  test 'find ingredient list' do
    nokoscan = NokoScanner.from_string @ings_list
  end

  # A Lexaur gets initialized properly
  test 'Lexaur tree initialized properly' do
    lex = Lexaur.new
    assert_kind_of Hash, lex.terminals
    assert_kind_of Hash, lex.nexts
  end

  # Build a Lexaur tree and access it
  test 'Lexaur tree built on strings' do
    lex = Lexaur.new
    str = 'word'
    str2 = 'two words'
    str4 = 'a very long string'
    lex.take str, str
    lex.take str2.split, str2
    lex.take str4.split, str4
    assert_equal [str], lex.find(str)
    assert_equal [str2], lex.find(str2)
    assert_equal [str4], lex.find(str4)
  end

  # Check stemming on a Lexaur tree
  test 'Lexaur stemming behaves appropriately' do
    # All these words should have the same stem, thus map onto the same lexaur entry
    words = %w{ computers computing compute computer }
    lex = Lexaur.new
    words.each { |word| lex.take word, 'comput' }
    assert_equal 1, lex.find(words[0]).count
    assert_equal lex.find(words[0]), lex.find(words[1])
    assert_equal lex.find(words[0]), lex.find(words[2])
    assert_equal lex.find(words[0]), lex.find(words[3])
  end

  test 'lexaur initialized from tags database' do
    lex = Lexaur.from_tags
    assert_not_empty lex.find('jalapeño peppers')
  end

  test 'lexaur chunks simple stream' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string'jalapeño' # Fail gracefully
    assert_nil lex.chunk(scanner)

    scanner = StrScanner.from_string 'jalapeño peppers'
    assert_not_nil lex.chunk(scanner) {|data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
      assert_nil stream.first
    }

    scanner = StrScanner.from_string 'jalapeño peppers, and more'
    assert_not_nil lex.chunk(scanner) { |data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
    }
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test
=begin
  def test_fail
    fail('Not implemented')
  end
=end
end
