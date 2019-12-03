require 'test_helper'
require 'scraping/scanner.rb'

class ScannerTest < ActiveSupport::TestCase

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
    nks.enclose 2,4
    assert_equal 4, nks.tokens.count
    assert nks.tokens[1].is_a?(String)
    assert nks.tokens[2].is_a?(NokoScanner)
    assert nks.tokens[3].is_a?(String)
    assert_equal [0,3], nks.elmt_bounds.map(&:last)

    # Enclose the last two strings
    nks = NokoScanner.from_string html
    nks.enclose 3,5
    assert_equal 4, nks.tokens.count
    assert nks.tokens[2].is_a?(String)
    assert nks.tokens[3].is_a?(NokoScanner)
    assert_equal [0], nks.elmt_bounds.map(&:last)

    # Enclose the first two strings
    nks = NokoScanner.from_string html
    nks.enclose 0,2
    assert_equal 4, nks.tokens.count
    assert nks.tokens[0].is_a?(NokoScanner)
    assert nks.tokens[1].is_a?(String)
    assert_equal [1], nks.elmt_bounds.map(&:last)

    # Enclose the last string
    nks = NokoScanner.from_string html
    nks.enclose 4,5
    assert_equal 5, nks.tokens.count
    assert nks.tokens[3].is_a?(String)
    assert nks.tokens[4].is_a?(NokoScanner)
    assert_equal [0], nks.elmt_bounds.map(&:last)

    # Enclose the first string
    nks = NokoScanner.from_string html
    nks.enclose 0,1
    assert_equal 5, nks.tokens.count
    assert nks.tokens[0].is_a?(NokoScanner)
    assert nks.tokens[1].is_a?(String)
    assert_equal [1], nks.elmt_bounds.map(&:last)
  end
end
