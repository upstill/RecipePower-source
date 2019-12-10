require 'test_helper'
require 'scraping/scanner.rb'

class ScannerTest < ActiveSupport::TestCase
  test 'tokenize' do
    assert_equal [], tokenize('')
    assert_equal [], tokenize(' ')
    assert_equal [ '('], tokenize('(')
    assert_equal [ 'a' ], tokenize('a')
    assert_equal [ "\n" ], tokenize("\n")
    str = "  abc d\n( kwjer   )\na"
    tokenlist = ["abc", "d", "\n", "(", "kwjer", ")", "\n", 'a']
    tokenoffsets = [2, 6, 7, 8, 10, 18, 19, 20, 21]
    assert_equal tokenlist, tokenize(str)
    remainder = tokenize(str) do |token, offset|
      assert_equal token, tokenlist.shift
      assert_equal offset, tokenoffsets.shift
    end
    assert_equal 1, tokenlist.length
    assert_equal 'a', remainder

    tokenlist = ["abc", "d", "\n", "(", "kwjer", ")", "\n", 'a']
    tokenoffsets = [2, 6, 7, 8, 10, 18, 19, 20, 21]
    str << ' '
    assert_equal tokenlist, tokenize(str)
    remainder = tokenize(str) do |token, offset|
      assert_equal token, tokenlist.shift
      assert_equal offset, tokenoffsets.shift
    end
    assert_equal 0, tokenlist.length
    assert_equal ' ', remainder
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
    assert_equal scanout.join(' '), nkdoc.inner_text
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

  test "simple text replacement in nkscanner" do
    html = "a simple undifferentiated text string"
    nks = NokoScanner.from_string html
    assert_equal 5, nks.tokens.count

    # Enclose two strings in the middle
    nks.enclose nks.token_starts[2],nks.token_starts[4]
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    assert_equal 4, nks.tokens.count
    assert nks.tokens[1].is_a?(String)
    assert nks.tokens[2].is_a?(NokoScanner)
    assert nks.tokens[3].is_a?(String)
    assert_equal [0,3], nks.elmt_bounds.map(&:last)

    # Enclose the last two strings
    nks = NokoScanner.from_string html
    nks.enclose nks.token_starts[3], nks.token_starts[5]
    assert_equal 4, nks.tokens.count
    assert nks.tokens[2].is_a?(String)
    assert nks.tokens[3].is_a?(NokoScanner)
    assert_equal [0], nks.elmt_bounds.map(&:last)

    # Enclose the first two strings
    nks = NokoScanner.from_string html
    nks.enclose nks.token_starts[0], nks.token_starts[2]
    assert_equal 4, nks.tokens.count
    assert nks.tokens[0].is_a?(NokoScanner)
    assert nks.tokens[1].is_a?(String)
    assert_equal [1], nks.elmt_bounds.map(&:last)

    # Enclose the last string
    nks = NokoScanner.from_string html
    nks.enclose nks.token_starts[4], nks.token_starts[5]
    assert_equal 5, nks.tokens.count
    assert nks.tokens[3].is_a?(String)
    assert nks.tokens[4].is_a?(NokoScanner)
    assert_equal [0], nks.elmt_bounds.map(&:last)

    # Enclose the first string
    nks = NokoScanner.from_string html
    nks.enclose nks.token_starts[0], nks.token_starts[1]
    assert_equal 5, nks.tokens.count
    assert nks.tokens[0].is_a?(NokoScanner)
    assert nks.tokens[1].is_a?(String)
    assert_equal [1], nks.elmt_bounds.map(&:last)
  end

  test 'element Bounds in text' do
    html = "<div class=\"upper div\"><div class=\"lower div\">\n<div class=\"lower left\">text1</div>\n<div class=\"lower right\">text2</div>\n</div></div>"
    nks = NokoScanner.from_string html
    assert_equal [0,1,6,7,12], nks.elmt_bounds.collect(&:last)
  end

  test "Replace tokens separated in tree" do
    html = "<div class=\"upper div\"><div class=\"lower div\">\n<div class=\"lower left\">text1</div>\n<div class=\"lower right\">text2</div>\n</div></div>"
    nks = NokoScanner.from_string html
    nks.enclose nks.token_starts[1], nks.token_starts[4]
    assert_equal html, nks.nkdoc.inner_html
    assert nks.tokens[0].is_a?(NokoScanner)
    assert_equal "<div class=\"np_elmt\">text1 text2</div>", nks.tokens[0].nkdoc.to_s
  end

  test "TextElmtData" do
    html = "<span>Beginning text </span>and then a random text stream<span> followed by more text"
    nks = NokoScanner.from_string html

    assert_equal [ 0, 15, 44 ], nks.elmt_bounds.map(&:last)
    ted = nks.text_elmt_data 0
    assert_equal '', ted.prior_text
    assert_equal 'Beginning text ', ted.subsq_text

    ted = nks.text_elmt_data 19
    assert_equal 'and ', ted.prior_text
    assert_equal 'then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data -19
    assert_equal 'and ', ted.prior_text
    assert_equal 'then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data 15
    assert_equal '', ted.prior_text
    assert_equal 'and then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data -15
    assert_equal 'Beginning text ', ted.prior_text
    assert_equal '', ted.subsq_text

    ted = nks.text_elmt_data -33
    assert_equal 'and then a random ', ted.prior_text
    assert_equal 'text stream', ted.subsq_text

    html = "<span>Beginning text</span>and then a random text stream<span>followed by more text"
    nks = NokoScanner.from_string html
    assert_equal [0, 10, 18, 23, 25, 32, 37, 52, 55, 60 ], nks.token_starts
    assert_equal [0, 14, 43], nks.elmt_bounds.map(&:last)

    ted = nks.text_elmt_data 14
    assert_equal '', ted.prior_text
    assert_equal 'and then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data -14
    assert_equal 'Beginning text', ted.prior_text
    assert_equal '', ted.subsq_text

    ted = nks.text_elmt_data 43
    assert_equal '', ted.prior_text
    assert_equal 'followed by more text', ted.subsq_text

    ted = nks.text_elmt_data -43
    assert_equal 'and then a random text stream', ted.prior_text
    assert_equal '', ted.subsq_text

    ted = nks.text_elmt_data -64
    assert_equal 'followed by more text', ted.prior_text
    assert_equal '', ted.subsq_text
  end
end
