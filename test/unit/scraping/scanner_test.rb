require 'test_helper'
require 'scraping/scanner.rb'

class ScannerTest < ActiveSupport::TestCase

  def check_integrity nks
    tn = 0
    elmt_bounds = nks.tokens.elmt_bounds
    nks.nkdoc.traverse do |node|
      if node.text?
        assert_equal node, elmt_bounds.nth_elmt(tn), "text elmt ##{tn} '#{node.to_s}' does not match '#{elmt_bounds.nth_elmt(tn).to_s}'"
        tn += 1
      end
    end
  end

  test 'tokenize' do
    # Break on em-dash
    assert_equal ['kwjer', '—', 'ekjrke'], tokenize('kwjer—ekjrke')
    # Break on dash
    assert_equal ['kwjer', '-', 'ekjrke'], tokenize('kwjer-ekjrke')
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
    scanner = StrScanner.new "Fourscore and seven years ago "
    assert_equal 'Fourscore', scanner.first
    assert_equal 'and seven', scanner.peek(2)
    assert_equal 'and seven', scanner.first(2)
  end

  test 'string boundaries' do
    scanner = StrScanner.new "We've got all the \"gang\" here for 1/2 hot minutes. Dig? {bracketed material }( parenthetical) [ with braces]."
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
      # assert_equal scanout.join(' '), nkdoc.inner_text
  end

  test 'string partitioning' do
    # Generic comma-delimited list
    scanner = StrScanner.new 'something, something and something else'
    scanners = scanner.partition
    assert_equal 3, scanners.count
    assert_equal 'something', scanners.shift.to_s
    assert_equal 'something', scanners.shift.to_s
    assert_equal 'something else', scanners.shift.to_s

    # Handle Oxford comma
    scanner = StrScanner.new 'something, something, and something else'
    scanners = scanner.partition
    assert_equal 3, scanners.count
    assert_equal 'something', scanners.shift.to_s
    assert_equal 'something', scanners.shift.to_s
    assert_equal 'something else', scanners.shift.to_s

    # Handle parenthesis
    scanner = StrScanner.new 'something, something (with noise, fury and other stuff) and something else'
    scanners = scanner.partition
    assert_equal 3, scanners.count
    assert_equal 'something', scanners.shift.to_s
    assert_equal 'something ( with noise , fury and other stuff )', scanners.shift.to_s
    assert_equal 'something else', scanners.shift.to_s

    # Handle Oxford comma and parenthesis
    scanner = StrScanner.new 'something, something, (with noise, fury and other stuff) and something else'
    scanners = scanner.partition
    assert_equal 4, scanners.count
    assert_equal 'something', scanners.shift.to_s
    assert_equal 'something', scanners.shift.to_s
    assert_equal '( with noise , fury and other stuff )', scanners.shift.to_s
    assert_equal 'something else', scanners.shift.to_s
  end

  def trstr str
    str.gsub! "\n", '\n'
    '\'' + str + '\''
  end

  # Test a scanner for properly delimiting lines
  def check_lines start_scanner, *lines
    ls = lines.collect { |line| trstr line }.join ', '
    puts "Checking #{trstr start_scanner.to_s} against #{ls}"
    # Once more, without enclosing the line
    scanner = start_scanner
    lines.each do |line|
      assert (scanner = scanner.toline), "...scanner ran out lacking #{trstr line}"
      assert scanner.to_s.strip.match(/^#{line}/), "...stumbled on #{trstr line}"
      scanner.first
    end
    refute scanner.toline, "scanner #{trstr start_scanner.to_s} had #{trstr scanner.to_s} left." # Should have exhausted the stream

    scanner = start_scanner
    lines.each do |line|
      scanner = scanner.toline true
      assert_equal line, scanner.to_s.strip, "...stumbled on #{trstr line}"
      scanner = start_scanner.past scanner
    end
    refute scanner.toline, "scanner #{trstr start_scanner.to_s} had #{trstr scanner.to_s} left." # Should have exhausted the stream
  end

  test 'toline text' do

    lines = [ 'blah de blah', '2 servings' ]

    html = "<br>blah de blah<br><br>2 servings<br><br>"
    check_lines NokoScanner.new(html), *lines

    text = "\nblah de blah\n\n2 servings\n\n"
    check_lines StrScanner.new(text), *lines

    text = "blah de blah\n2 servings"
    check_lines StrScanner.new(text), *lines

    html = "blah de blah<br>2 servings"
    check_lines NokoScanner.new(html), *lines

    str = "first line \n second line \n third line \n"
    scanner = StrScanner.new str
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

=begin
    scanner = StrScanner.new "\n\n\n" # Should produce three blank lines
    line1 = scanner.toline
    assert_equal "\n \n \n", line1.to_s
    line2 = line1.rest.toline
    assert_equal "\n \n", line2.to_s
    line3 = line2.rest.toline
    assert_equal "\n", line3.to_s
    assert_nil line3.rest.toline

    scanner = StrScanner.new "\nend" # Should produce a blank, then 'end'
    line1 = scanner.toline true
    assert_equal "\n", line1.to_s
    line2 = scanner.rest.toline true
    assert_equal 'end', line2.to_s

    scanner = StrScanner.new "\n\n\n" # Should produce three blank lines
    line1 = scanner.toline true
    assert_equal "\n", line1.to_s
    line2 = scanner.rest.toline true
    assert_equal "\n", line2.to_s
    line3 = scanner.rest.rest.toline true
    assert_equal "\n", line3.to_s
    assert_nil scanner.rest.rest.rest.toline true
=end
  end

  test 'for_each' do
    str = "\n\nfirst line \n second line \n\n\n third line \nfourth line\n\n\n"
    # What they should come out as
    lines = [ "first line", "second line", "third line", 'fourth line']

    # Test StrScanner
    scanner = StrScanner.new str
    scanners = scanner.for_each(:inline => true) do |ls|
      assert_equal ls.to_s, (line = lines.shift)
      ls
    end
    assert_equal 4, scanners.count

    # Test NokoScanner
    scanner = NokoScanner.new str
    lines = [ "first line", "second line", "third line", 'fourth line']
    scanners = scanner.for_each(:inline => true) do |ls|
      assert_equal ls.to_s, (line = lines.shift)
      ls
    end
    assert_equal 4, scanners.count

    html = "<h1>title</h1><br><br><br>some stuff<h1>another title</h1>"
    scanner = NokoScanner.new html
    assert_equal %w{title some stuff another title}, scanner.tokens
    titles = ['title', 'another title']
    scanner.for_each(:in_css_match => 'h1') do |ls|
      assert_equal titles.shift, ls.to_s
    end

    html = "<h1>title</h1><br><br><br>some stuff <h1>another title</h1>"
    scanner = NokoScanner.new html
    titles = ['some stuff another title']
    scanner.for_each(:at_css_match => 'br') do |ls|
      assert_equal titles.shift, ls.to_s
    end
    assert_empty titles, "Failed to find all the strings after <br> in '#{html}'"

    html = "<h1>title</h1><br><br><br>some stuff <h1>another title</h1>"
    scanner = NokoScanner.new html
    titles = ['some stuff another title', '']
    scanner.for_each(:after_css_match => 'h1') do |ls|
      assert_equal titles.shift, ls.to_s
    end
    assert_empty titles, "Failed to find all the strings after <h1> in '#{html}'"

    html = "<h1>title</h1><h1>another title</h1>"
    scanner = NokoScanner.new html
    titles = ['another title']
    scanner.for_each(:after_css_match => 'h1') do |ls|
      assert_equal titles.shift, ls.to_s
    end
    assert_empty titles, "Failed to find all the strings after <h1> in '#{html}'"

    html = "<h1>title</h1><br><br><br>some stuff<h1>another title</h1>"
    scanner = NokoScanner.new html
    titles = ['some stuff another title']
    scanner.for_each(:at_css_match => 'br') do |ls|
      assert_equal titles.shift, ls.peek(100)
    end
    assert_empty titles, "Failed to find all the strings at <br> in '#{html}'"
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
      nokoscan.for_each((within ? :inline : :atline) => true) do |subscanner|
        assert_equal seeking.shift, subscanner.to_s
      end
      seeking.map do |str|
        result = nokoscan.toline(within).to_s
        assert_equal str, result
        nokoscan = nokoscan.rest
      end
    end
    html = "top-level <br>afterbr <span class='rp_elmt rp_text'>within span</span> after\nspan"
    # test_str html, ["top-level afterbr within span after\nspan"]
    test_str html, ['top-level', "afterbr within span after", 'span'], true
    # Should get the same result independent of spacing
    html = "top-level <br> afterbr<span class='rp_elmt rp_text'>within span</span>after\nspan"
    test_str html, ["top-level  afterbrwithin spanafter\nspan", "afterbrwithin spanafter\nspan", "span"]
    test_str html, ['top-level', "afterbrwithin spanafter", 'span'], true
    html = "top-level <br>afterbr<span class='rp_elmt rp_text'>    within span</span>  after\nspan"
    test_str html, ["top-level afterbr    within span  after\nspan", "afterbr    within span  after\nspan", "span"]
    test_str html, ['top-level', "afterbr    within span  after", 'span'], true
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
    nks = NokoScanner.new html
    assert_equal 5, nks.tokens.count
    assert_equal [0], nks.elmt_bounds.map(&:last)

    # Enclose two strings in the middle
    nks.enclose_tokens 2, 4
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    # assert_equal 4, nks.tokens.count
    # assert nks.tokens[1].is_a?(String)
    # assert nks.tokens[2].is_a?(NokoScanner)
    # assert nks.tokens[3].is_a?(String)
    assert_equal [0, 9, 30], nks.elmt_bounds.map(&:last)

    # Enclose the last two strings
    nks = NokoScanner.new html
    nks.enclose_tokens 3,5
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 4, nks.tokens.count
    #assert nks.tokens[2].is_a?(String)
    #assert nks.tokens[3].is_a?(NokoScanner)
    assert_equal [0, 26], nks.elmt_bounds.map(&:last)

    # Enclose the first two strings
    nks = NokoScanner.new html
    nks.enclose_tokens 0,2
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 4, nks.tokens.count
    #assert nks.tokens[0].is_a?(NokoScanner)
    #assert nks.tokens[1].is_a?(String)
    assert_equal [0, 8], nks.elmt_bounds.map(&:last)

    # Enclose the last string
    nks = NokoScanner.new html
    nks.enclose_tokens 4,5
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 5, nks.tokens.count
    #assert nks.tokens[3].is_a?(String)
    #assert nks.tokens[4].is_a?(NokoScanner)
    assert_equal [0, 31], nks.elmt_bounds.map(&:last)

    # Enclose the first string
    nks = NokoScanner.new html
    nks.enclose_tokens 0,1
    check_integrity nks
    assert_equal html, nks.nkdoc.inner_text  # The enclosure shouldn't change the text stream
    #assert_equal 5, nks.tokens.count
    #assert nks.tokens[0].is_a?(NokoScanner)
    #assert nks.tokens[1].is_a?(String)
    assert_equal [0, 1], nks.elmt_bounds.map(&:last)
  end

  test 'element Bounds in text' do
    html = "<div class=\"upper div\"><div class=\"lower div\">\n<div class=\"lower left\">text1</div>\n<div class=\"lower right\">text2</div>\n</div></div>"
    nks = NokoScanner.new html
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
    nks = NokoScanner.new html
    nks.enclose_tokens 0, 2, tag: 'div'
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class=\"upper div rp_elmt\">
      <span>text1 </span>
      text2
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
    nks = NokoScanner.new html
    nks.enclose_tokens 0,2, tag: 'div'
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div rp_elmt">
        text2 
        <span>text1</span>
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
    nks = NokoScanner.new html
    nks.enclose_tokens 0,2, tag: 'div'
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div rp_elmt">
        <span>text1 </span>
        <span>text2</span>
</div>
EOF
    expected = expected.gsub(/\n+\s*/, '')
    assert_equal expected, nks.nkdoc.to_s.gsub(/\n+\s*/, '')
  end

  test 'enclose by token indices' do
    html = "\n<li class=\"simple-list__item js-checkbox-trigger ingredient\">\nGarnish: 1 <a href=\"https://www.thespruceeats.com/cut-citrus-garnishes-for-cocktails-759982\" data-component=\"link\" data-source=\"inlineLink\" data-type=\"internalLink\" data-ordinal=\"1\">orange slice</a>\n</li>\n<li class=\"simple-list__item js-checkbox-trigger ingredient\">\nGarnish: 1 <a href=\"https://www.thespruceeats.com/the-truth-about-maraschino-cherries-759977\" data-component=\"link\" data-source=\"inlineLink\" data-type=\"internalLink\" data-ordinal=\"1\">cherry</a>\n</li>"
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    nkt = nokoscan.tokens
    check_integrity nokoscan
    assert_equal '1 orange slice', nkt.text_from(2,5)
    nkt.enclose_tokens 3, 5, :rp_elmt_class => :rp_ingspec, :tag => 'span'
    assert_equal '1 orange slice', nkt.text_from(2,5)
    nkt.enclose_tokens 4, 5, :rp_elmt_class => :rp_ingredient_tag, :tag => 'span'
    assert_equal '1 orange slice', nkt.text_from(2,5)
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
    nks = NokoScanner.new html
    assert_equal 0...2, nks.tokens.dom_range('div.div')
    assert_equal 1...2, nks.tokens.dom_range('div.right')
    html = "some text<span>and spanned text</span>extended"
    nks = NokoScanner.new html
    assert_equal 2...3, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "some text <span>and spanned text</span> extended"
    nks = NokoScanner.new html
    assert_equal 2...5, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "some text<span> and spanned text </span>extended"
    nks = NokoScanner.new html
    assert_equal 2...5, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "<span>some spanned text</span>"
    nks = NokoScanner.new html
    assert_equal 0...3, nks.tokens.dom_range('span') # Include only tokens that are entirely w/in the DOM element

    html = "<span> some spanned text </span>"
    nks = NokoScanner.new html
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
    nks = NokoScanner.new html
    nks.enclose_tokens 0, 2, tag: 'div'
    check_integrity nks
    # assert nks.tokens[0].is_a?(NokoScanner)
    expected = <<EOF
<div class="upper div">
  <div class="lower div rp_elmt">
    <div class="lower left">
      <span>text1 </span>
    </div>
    <div class="lower right">
      text2
    </div>
  </div>
</div>
EOF
    expected = expected.gsub(/\n+\s*/, '')
    assert_equal expected, nks.nkdoc.to_s.gsub(/\n+\s*/, '')
  end

  test "TextElmtData" do
    html = "<span>Beginning text </span>and then a random text stream<span> followed by more text"
    nks = NokoScanner.new html

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
    nks = NokoScanner.new html
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
    nks.enclose_selection 'div/p[position()=2]/span[position()=1]/text()', 0,
                             'div/p[position()=2]/span[position()=2]/text()', 21,
                             tag: 'div', rp_elmt_class: 'rp_inglist'
    p = nkdoc.xpath('div/p[position()=2]').first
    assert_equal 'div', p.next.name
    assert_equal 'p', p.next.next.name

    html = '<div class="rp_elmt rp_recipe">
<p>Like its cousin the Amaretto Sour.</p>
<p>ice, combine <span>1 ounce of bourbon, 1 ounce of Frangelico, 3/4 ounce lemon juice</span> blah blah blah.</p></div>'
    nkdoc = Nokogiri::HTML.fragment(html)
    nks = NokoScanner.new nkdoc
    assert_equal 'span', nkdoc.xpath('div/p[position()=2]/span[position()=1]').first.name
    nks.enclose_selection 'div/p[position()=2]/span[position()=1]/text()', 0,
                             'div/p[position()=2]/span[position()=1]/text()', 63,
                             tag: 'div', rp_elmt_class: 'rp_inglist'
    p = nkdoc.xpath('div/p[position()=2]').first
    assert_equal 'div', p.next.name
    assert_equal 'p', p.next.next.name

    html = '<div class="rp_elmt rp_recipe">
<p>Like its cousin the Amaretto Sour.</p>
<p>ice, combine 1 ounce of bourbon, 1 ounce of Frangelico, 3/4 ounce lemon juice blah blah blah.</p></div>'
    nkdoc = Nokogiri::HTML.fragment(html)
    nks = NokoScanner.new nkdoc
    nks.enclose_selection 'div/p[position()=2]/text()', 13,
                             'div/p[position()=2]/text()', 76,
                             tag: 'div', rp_elmt_class: 'rp_inglist'
    p = nkdoc.xpath('div/p[position()=2]').first
    assert_equal 'div', p.next.name
    assert_equal 'p', p.next.next.name
    
  end
end
