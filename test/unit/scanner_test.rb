require 'test_helper'
require 'scraping/scanner.rb'

class ScannerTest < ActiveSupport::TestCase
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
EOF
  end

  test 'find ingredient list' do
    nokoscan = NokoScanner.from_string @ings_list
  end

  test 'basic stream operations' do
    scanner = StrScanner.from_string "Fourscore and seven years ago "
    assert_equal 'Fourscore', scanner.first
    assert_equal 'and seven', scanner.peek(2)
    assert_equal 'and seven', scanner.first(2)
  end

  test 'string boundaries' do
    scanner = StrScanner.from_string "We've got all the \"gang\" here for 1/2 hot minutes. Dig? {bracketed material }( parenthetical) [ with braces]."
    assert_equal ["We've", "got", "all", "the", "\"gang\"", "here", "for", "1/2", "hot", "minutes", ".", "Dig", "?", "{", "bracketed", "material", "}", "(", "parenthetical", ")", "[", "with", "braces", "]", "."], scanner.strings
  end

  test 'basic nkscanner test' do
    html = 'top-level text<span>spanned text</span><div>div opener<div>child<span>child span</span><a>child link </a></div>and more top-level text'
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    scanout = []
    while ch = nokoscan.first
      scanout << ch
    end
    assert_equal scanout, nokoscan.strings
    assert_equal scanout[1..-1].join(' '), nkdoc.inner_text
  end

  test 'nkscanner with rp_elmt' do
    html = <<EOF
top-level text<span>spanned text</span>
<div class="rp_elmt">rp_elmt div</div><div>child<span>child span</span><a>child link </a></div>and more top-level text
<br>with newline<p>and new paragraph</p>
EOF
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    scanout = []
    while ch = nokoscan.first
      if ch.is_a?(String)
        scanout << ch
      else
        scanout += ch.strings
      end
    end
    assert_equal scanout, nokoscan.strings
  end
end
