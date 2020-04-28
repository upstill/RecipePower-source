require 'test_helper'
require 'scraping/scanner.rb'

class ScannerTest < ActiveSupport::TestCase

  def check_integrity nks
    tn = 0
    nks.nkdoc.traverse do |node|
      if node.text?
        assert_equal node, nks.elmt_bounds[tn].first, "node '#{node.to_s}' does not match '#{nks.elmt_bounds[tn].first.to_s}'"
        tn += 1
      end
    end
  end

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
      assert_equal token, tokenlist.shift, "wrong token at offset #{offset} in #{str}"
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
    html = 'top-level text<span class=\'rp_elmt rp_text\'>spanned text</span><div>div opener<div>child<span>child span</span><a>child link </a></div>and more top-level text'
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    check_integrity nokoscan
    scanout = []
    while ch = nokoscan.first
      scanout << ch
    end
    assert_equal scanout, nokoscan.strings
    assert_equal scanout.join(' '), nkdoc.inner_text
  end

  test 'toline text' do
    str = "first line \n second line \n third line \n"
    scanner = StrScanner.from_string str
    line1 = scanner.toline
    assert_equal str, line1.to_s
    line2 = line1.rest.toline
    assert_equal "second line \n third line \n", line2.to_s
    line3 = line2.rest.toline
    assert_equal "third line \n", line3.to_s
    line4 = line3.rest.toline
    assert_nil line4

    line1 = scanner.toline true
    assert_equal "first line \n", line1.to_s
    line2 = scanner.rest.toline true
    assert_equal "second line \n", line2.to_s

    scanner = StrScanner.from_string "\n\n\n" # Should produce three blank lines
    line1 = scanner.toline
    assert_equal "\n \n \n", line1.to_s
    line2 = line1.rest.toline
    assert_equal "\n \n", line2.to_s
    line3 = line2.rest.toline
    assert_equal "\n", line3.to_s
    assert_nil line3.rest.toline

    scanner = StrScanner.from_string "\nend" # Should produce a blank, then 'end'
    line1 = scanner.toline true
    assert_equal "\n", line1.to_s
    line2 = scanner.rest.toline true
    assert_equal 'end', line2.to_s

    scanner = StrScanner.from_string "\n\n\n" # Should produce three blank lines
    line1 = scanner.toline true
    assert_equal "\n", line1.to_s
    line2 = scanner.rest.toline true
    assert_equal "\n", line2.to_s
    line3 = scanner.rest.rest.toline true
    assert_equal "\n", line3.to_s
    assert_nil scanner.rest.rest.rest.toline true
  end

  test 'is_at' do
    def test_str html, seeking, spec
      nkdoc = Nokogiri::HTML.fragment html
      nokoscan = NokoScanner.new nkdoc
      check_integrity nokoscan
      while nokoscan.more? do
        if found = nokoscan.is_at?(spec)
          assert_equal seeking, found.to_s
        end
        nokoscan = nokoscan.rest
      end
    end
    html = "top-level <br>afterbr <span class='rp_elmt rp_text'>within span</span> after\nspan"
    test_str html, "within span", within_elmt: 'span'
    test_str html,  "after\nspan", after_elmt: 'span'
    test_str html,  "afterbr within span after\nspan", after_elmt: 'br'
    # Should get the same result independent of spacing
    html = "top-level <br> afterbr<span class='rp_elmt rp_text'>within span</span>after\nspan"
    test_str html, "text", within_elmt: 'span'
    test_str html,  "text after\nspan", after_elmt: 'span'
    test_str html,  "afterbrwithin spanafter\nspan", after_elmt: 'br'
    html = "top-level <br>afterbr<span class='rp_elmt rp_text'>    within span</span>  after\nspan"
    test_str html, "within span", within_elmt: 'span'
    test_str html,  "after\nspan", after_elmt: 'span'
    test_str html,  "afterbr    within span  after\nspan", after_elmt: 'br'
  end

  test 'toline tag' do
    # test_str takes an html string, and an array of strings that should be found in that html on a line-by-line basis.
    # 'within' is a flag indicating whether the strings should be confined to individual lines, or just begin
    def test_str html, seeking, within=false
      nkdoc = Nokogiri::HTML.fragment html
      nokoscan = NokoScanner.new nkdoc
      check_integrity nokoscan
      # 'seeking' is an array of strings to match successively
      seeking.map do |str|
        result = nokoscan.toline(within).to_s
        assert_equal str, result
        nokoscan = nokoscan.rest
      end
    end
    html = "top-level <br>afterbr <span class='rp_elmt rp_text'>within span</span> after\nspan"
    # test_str html, ["top-level afterbr within span after\nspan"]
    test_str html, ['top-level', "afterbr within span after\n", 'span'], true
    # Should get the same result independent of spacing
    html = "top-level <br> afterbr<span class='rp_elmt rp_text'>within span</span>after\nspan"
    test_str html, ["top-level  afterbrwithin spanafter\nspan"]
    test_str html, ['top-level', "afterbrwithin spanafter\n", 'span'], true
    html = "top-level <br>afterbr<span class='rp_elmt rp_text'>    within span</span>  after\nspan"
    test_str html, ["top-level afterbr    within span  after\nspan"]
    test_str html, ['top-level', "afterbr    within span  after\n", 'span'], true
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
    assert_equal [0], nks.elmt_bounds.map(&:last)

    # Enclose two strings in the middle
    nks.enclose_by_token_indices 2, 4
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    # assert_equal 4, nks.tokens.count
    # assert nks.tokens[1].is_a?(String)
    # assert nks.tokens[2].is_a?(NokoScanner)
    # assert nks.tokens[3].is_a?(String)
    assert_equal [0, 9, 30], nks.elmt_bounds.map(&:last)

    # Enclose the last two strings
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 3,5
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 4, nks.tokens.count
    #assert nks.tokens[2].is_a?(String)
    #assert nks.tokens[3].is_a?(NokoScanner)
    assert_equal [0, 26], nks.elmt_bounds.map(&:last)

    # Enclose the first two strings
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 0,2
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 4, nks.tokens.count
    #assert nks.tokens[0].is_a?(NokoScanner)
    #assert nks.tokens[1].is_a?(String)
    assert_equal [0, 8], nks.elmt_bounds.map(&:last)

    # Enclose the last string
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 4,5
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 5, nks.tokens.count
    #assert nks.tokens[3].is_a?(String)
    #assert nks.tokens[4].is_a?(NokoScanner)
    assert_equal [0, 31], nks.elmt_bounds.map(&:last)

    # Enclose the first string
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 0,1
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 5, nks.tokens.count
    #assert nks.tokens[0].is_a?(NokoScanner)
    #assert nks.tokens[1].is_a?(String)
    assert_equal [0, 1], nks.elmt_bounds.map(&:last)
  end

  test 'element Bounds in text' do
    html = "<div class=\"upper div\"><div class=\"lower div\">\n<div class=\"lower left\">text1</div>\n<div class=\"lower right\">text2</div>\n</div></div>"
    nks = NokoScanner.from_string html
    assert_equal [0,1,6,7,12], nks.elmt_bounds.collect(&:last)
  end

  test "Replace tokens in span element" do
    html = <<EOF
<div class="upper div">
      <span>text1 </span>
      text2
</div>
EOF
    html = html.gsub(/\n+\s*/, '')
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 0, 2
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div">
    <div class="rp_elmt">
        <span>text1 </span>
        text2
    </div>
</div>
EOF
    expected = expected.gsub(/\n+\s*/, '')
    assert_equal expected, nks.nkdoc.to_s.gsub(/\n+\s*/, '')

    # Span at the other end
    html = <<EOF
<div class="upper div">
      text2 
      <span>text1</span>
</div>
EOF
    html = html.gsub(/\n+\s*/, '')
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 0,2
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div">
    <div class="rp_elmt">
        text2 
        <span>text1</span>
    </div>
</div>
EOF
    expected = expected.gsub(/\n+\s*/, '')
    assert_equal expected, nks.nkdoc.to_s.gsub(/\n+\s*/, '')
    # Span at the other end
    html = <<EOF
<div class="upper div">
      <span>text1 </span>
      <span>text2</span>
</div>
EOF
    html = html.gsub(/\n+\s*/, '')
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 0,2
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div">
    <div class="rp_elmt">
        <span>text1 </span>
        <span>text2</span>
    </div>
</div>
EOF
    expected = expected.gsub(/\n+\s*/, '')
    assert_equal expected, nks.nkdoc.to_s.gsub(/\n+\s*/, '')
  end

  test "Find token positions by DOM selector" do
    html = <<EOF
<div class="upper div">
  <div class="lower div">
    <div class="lower left">
      <span>text1 </span>
    </div>
    <div class="lower right">
      text2
    </div>
  </div>
</div>
EOF
    html = html.gsub(/\n+\s*/, '')
    nks = NokoScanner.from_string html
    assert_equal 0...2, nks.tokens.dom_range('div.div')
    assert_equal 1...2, nks.tokens.dom_range('div.right')
    html = "some text<span>and spanned text</span>extended"
    nks = NokoScanner.from_string html
    assert_equal 2...3, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "some text <span>and spanned text</span> extended"
    nks = NokoScanner.from_string html
    assert_equal 2...5, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "some text<span> and spanned text </span>extended"
    nks = NokoScanner.from_string html
    assert_equal 2...5, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "<span>some spanned text</span>"
    nks = NokoScanner.from_string html
    assert_equal 0...3, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "<span> some spanned text </span>"
    nks = NokoScanner.from_string html
    assert_equal 0...3, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element
  end

  test "Replace tokens separated in tree" do
    html = <<EOF
<div class="upper div">
  <div class="lower div">
    <div class="lower left">
      <span>text1 </span>
    </div>
    <div class="lower right">
      text2
    </div>
  </div>
</div>
EOF
    html = html.gsub(/\n+\s*/, '')
    nks = NokoScanner.from_string html
    nks.enclose_by_token_indices 0, 2
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div">
  <div class="lower div">
    <div class="rp_elmt">
      <div class="lower left">
        <span>text1 </span>
      </div>
      <div class="lower right">
        text2
      </div>
    </div>
  </div>
</div>
EOF
    expected = expected.gsub(/\n+\s*/, '')
    assert_equal expected, nks.nkdoc.to_s.gsub(/\n+\s*/, '')
  end

  test "TextElmtData" do
    html = "<span>Beginning text </span>and then a random text stream<span> followed by more text"
    nks = NokoScanner.from_string html

    assert_equal [ 0, 15, 44 ], nks.elmt_bounds.map(&:last)
    ted = nks.text_elmt_data 0
    assert_equal '', ted.prior_text
    assert_equal 'Beginning text ', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(19)
    assert_equal 'and ', ted.prior_text
    assert_equal 'then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(-19)
    assert_equal '', ted.prior_text
    assert_equal 'and then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(15)
    assert_equal '', ted.prior_text
    assert_equal 'and then a random text stream', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(-15)
    assert_equal 'Beginning ', ted.prior_text
    assert_equal 'text ', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(-33)
    assert_equal 'and then a ', ted.prior_text
    assert_equal 'random text stream', ted.subsq_text

    html = "<span>Beginning text</span>and then a random text stream<span>followed by more text"
    nks = NokoScanner.from_string html
    assert_equal [0, 10, 18, 23, 25, 32, 37, 52, 55, 60 ], nks.token_starts
    assert_equal [0, 14, 43], nks.elmt_bounds.map(&:last)

    # Landing in the middle of a token, the pointer should retreat to the token's beginning, with associated text element
    ted = nks.text_elmt_data nks.token_index_for(14)
    assert_equal 'Beginning ', ted.prior_text
    assert_equal 'text', ted.subsq_text

    # A terminating mark landing in the middle of a token should mark the END of the token
    ted = nks.text_elmt_data nks.token_index_for(-14)
    assert_equal 'Beginning ', ted.prior_text
    assert_equal 'text', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(43)
    assert_equal 'stream', ted.subsq_text
    assert_equal 'and then a random text ', ted.prior_text

    ted = nks.text_elmt_data nks.token_index_for(-43)
    assert_equal 'and then a random text ', ted.prior_text
    assert_equal 'stream', ted.subsq_text

    ted = nks.text_elmt_data nks.token_index_for(-64)
    assert_equal 'followed by more ', ted.prior_text
    assert_equal 'text', ted.subsq_text
  end

  test 'pathfinding' do
    html = '<div class="rp_elmt rp_recipe">
<p>Like its cousin the Amaretto Sour.</p>
<p>ice, combine <span>1 ounce of bourbon</span>, 1 ounce of Frangelico, <span>3/4 ounce lemon juice</span> blah blah blah.</p></div>'
    nkdoc = Nokogiri::HTML.fragment(html)
    nks = NokoScanner.new nkdoc
    assert_equal 'span', nkdoc.xpath('div/p[position()=2]/span[position()=1]').first.name
    assert_equal 'span', nkdoc.xpath('div/p[position()=2]/span[position()=2]').first.name
    nks.enclose_by_selection 'div/p[position()=2]/span[position()=1]/text()', 0,
                             'div/p[position()=2]/span[position()=2]/text()', 21,
                             tag: 'div', classes: 'rp_inglist'
    p = nkdoc.xpath('div/p[position()=2]').first
    assert_equal 'div', p.next.name
    assert_equal 'p', p.next.next.name

    html = '<div class="rp_elmt rp_recipe">
<p>Like its cousin the Amaretto Sour.</p>
<p>ice, combine <span>1 ounce of bourbon, 1 ounce of Frangelico, 3/4 ounce lemon juice</span> blah blah blah.</p></div>'
    nkdoc = Nokogiri::HTML.fragment(html)
    nks = NokoScanner.new nkdoc
    assert_equal 'span', nkdoc.xpath('div/p[position()=2]/span[position()=1]').first.name
    nks.enclose_by_selection 'div/p[position()=2]/span[position()=1]/text()', 0,
                             'div/p[position()=2]/span[position()=1]/text()', 63,
                             tag: 'div', classes: 'rp_inglist'
    p = nkdoc.xpath('div/p[position()=2]').first
    assert_equal 'div', p.next.name
    assert_equal 'p', p.next.next.name

    html = '<div class="rp_elmt rp_recipe">
<p>Like its cousin the Amaretto Sour.</p>
<p>ice, combine 1 ounce of bourbon, 1 ounce of Frangelico, 3/4 ounce lemon juice blah blah blah.</p></div>'
    nkdoc = Nokogiri::HTML.fragment(html)
    nks = NokoScanner.new nkdoc
    nks.enclose_by_selection 'div/p[position()=2]/text()', 13,
                             'div/p[position()=2]/text()', 76,
                             tag: 'div', classes: 'rp_inglist'
    p = nkdoc.xpath('div/p[position()=2]').first
    assert_equal 'div', p.next.name
    assert_equal 'p', p.next.next.name
    
  end
end
