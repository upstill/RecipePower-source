require 'test_helper'
require './lib/css_utils'
class ParseCSSTest < ActiveSupport::TestCase
  def setup
    html =<<EOL
  <div class="top">
		<h1 class="mytitle" value="Geekzone">GeeksforGeeks</h1>
		
		<!-- Since we have used * with str, all items with
			str in them are selected -->
		<div class="first_str" id="div1" data-testid="The Div1 Tested">The first div element.</div>
		<div class="second" id="div2"data-testid="The Div2 Tested">The second div element.</div>
		<div class="my-strt" id="div3"data-testid="The Div3 Tested">The third div element.</div>
		<p class="pgph"><span class="sp1">Paragraph One</span></p>
		<p class="pgph"><span class="sp1">Paragraph Two</span></p>
  </div>
EOL
    @doc = Nokogiri::HTML.fragment html
    @handler = CSSExtender.new
  end

  # Test a CSS match against different Nokogiri search options.
  # If count is provided, it's the number of matching elements expected
  def try_all *args, count: nil
    assert_not_nil @doc.at_css(*args)
    [ @doc.css(*args), @doc.search(*args)].each do |nodeset|
      if count
        assert_equal count, nodeset.count
      else
        assert_not_empty nodeset
      end
      nodeset.each { |node| assert nknode_matches?(node, *args) }
    end
  end

  def test1 selector, count, arg1=nil
    args = CSSExtender.args(selector)
    assert_equal arg1, args[0] if arg1
    assert_equal count, @doc.css(*args).count
  end

  test 'all' do
    try_all 'h1:regex("zone", "value")', @handler, count: 1
    try_all 'div.top', count: 1
    try_all 'div.top h1', count: 1
    try_all 'div.top h1:inclass("yti")', @handler, count: 1
    try_all 'div:inclass("str")', @handler, count: 2
  end

  test 'css extender' do
    test1 'p.gph$ span./sp[12]/', 2
    test1 'p./^pgph$/ span', 2
    test1 'div#div1', 1
    test1 'div#div*', 3
    test1 'div.top', 1
    test1 'div.top h1', 1
    test1 'p.pgph', 2
    test1 'p.^pg span.sp*', 2
    test1 'p.*g*h$ span', 2
    test1 'p./pgph/ span', 2
    test1 'p./^pg/ span', 2
    test1 'p./^pg$/ span', 0
  end

  test 'attribute selectors' do
    # A straight attribute specifier should get passed through
    test1 'div[data-testid]', 3, 'div[data-testid]'
    test1 '[data-testid]', 3, '[data-testid]'
    test1 'div[data-testid="The Div1 Tested"]', 1, 'div[data-testid="The Div1 Tested"]'
    # Quotes shouldn't matter
    test1 'div[data-testid=The Div1 Tested]', 1, 'div[data-testid="The Div1 Tested"]'

    # Metacharacters in a quoted specifier are ignored. Output == input
    test1 'div[data-testid="Div?"]', 0, 'div[data-testid="Div?"]'
    test1 'div[data-testid="^Div"]', 0, 'div[data-testid="^Div"]'
    test1 'div[data-testid="Div?$"]', 0, 'div[data-testid="Div?$"]'

    # A simple regex should get passed in without modification and do a simple match
    test1 'div[data-testid=/Div1/]', 1, "div:regex('Div1', 'data-testid')"
    test1 'div[data-testid=/Div?/]', 3, "div:regex('Div?', 'data-testid')"
    test1 'div[data-testid=/Tested$/]', 3, "div:regex('Tested$', 'data-testid')"
    test1 'div[data-testid=/^Div1/]', 0, "div:regex('^Div1', 'data-testid')"
    test1 'div[data-testid=/^The/]', 3, "div:regex('^The', 'data-testid')"

    test1 'div[data-testid*=/Div1/]', 1, "div:regex('Div1', 'data-testid')"
    test1 'div[data-testid^="Div1"]', 0, "div:regex('^Div1', 'data-testid')"
    test1 'div[data-testid*="Div1"]', 1, "div:regex('Div1', 'data-testid')"
    test1 'div[data-testid^="The"]', 3, "div:regex('^The', 'data-testid')"
    test1 'div[data-testid$="Tested"]', 3, "div:regex('Tested$', 'data-testid')"
    test1 'div[data-testid$="Div1"]', 0, "div:regex('Div1$', 'data-testid')"
  end
end