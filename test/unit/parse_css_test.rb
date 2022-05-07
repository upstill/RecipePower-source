require 'test_helper'
require './lib/css_utils'
class ParseCSSTest < ActiveSupport::TestCase
  def setup
    html =<<EOL
  <div class="top">
		<h1 class="mytitle" value="Geekzone">GeeksforGeeks</h1>
		
		<!-- Since we have used * with str, all items with
			str in them are selected -->
		<div class="first_str" id="div1">The first div element.</div>
		<div class="second" id="div2">The second div element.</div>
		<div class="my-strt" id="div3">The third div element.</div>
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

  test 'all' do
    try_all 'h1:regex("zone", "value")', @handler, count: 1
    try_all 'div.top', count: 1
    try_all 'div.top h1', count: 1
    try_all 'div.top h1:inclass("yti")', @handler, count: 1
    try_all 'div:inclass("str")', @handler, count: 2
  end

  test 'css extender' do

    args = CSSExtender.args('div#div1')
    assert_equal 1, @doc.css(*args).count

    args = CSSExtender.args('div#div*')
    assert_equal 3, @doc.css(*args).count

    args = CSSExtender.args('div.top')
    assert_equal 1, @doc.css(*args).count

    args = CSSExtender.args('div.top h1')
    assert_equal 1, @doc.css(*args).count

    args = CSSExtender.args('p.pgph')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p./^pgph$/ span')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p.^pg span.sp*')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p.gph$ span./sp[12]/')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p.*g*h$ span')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p./pgph/ span')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p./^pg/ span')
    assert_equal 2, @doc.css(*args).count

    args = CSSExtender.args('p./^pg$/ span')
    assert_equal 0, @doc.css(*args).count
  end
end