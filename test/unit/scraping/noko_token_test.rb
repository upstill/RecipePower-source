require 'test_helper'
require 'scraping/scanner.rb'

class NokoTokenTest < ActiveSupport::TestCase

  def initialize_doc html
    @nkdoc = Nokogiri::HTML.fragment html
    @nokoscan = NokoScanner.new @nkdoc
    @nokotokens = @nokoscan.tokens
  end

  def initialize_doc_from_file fname
    initialize_doc File.read fname
  end

  def text_element_containing text
    te = nil
    @nkdoc.traverse { |node| te = node if node.text? && node.text.match(text) }
    te
  end

  def text_element_data_containing text
    ted = text_element_containing 'more'
  end

  test 'correct tokenizing' do
    initialize_doc '1/2 cup'
    assert_equal [ '1/2', 'cup' ], @nokotokens
    initialize_doc '8 oz/1 cup'
    assert_equal [ '8', 'oz', '/', '1', 'cup'], @nokotokens
  end

  test 'text element finder' do
    initialize_doc '<div>starting<span>text</span><div><p><br><b>more text</b></p></div></div>'
    te = text_element_containing 'more'
    assert_not_nil te
    assert_equal 'more text', te.text
  end

  test 'simple node enclosure' do
    initialize_doc '<div>starting<span>text</span><div><p><br><b>more text</b></p></div></div>'
    ted = text_element_data_containing 'more'
    # Go directly to assemble the tree within Nokogiri
    newtree = assemble_tree_from_nodes ted, ted, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    # @nokotokens.enclose_by_text_elmt_data ted, ted, tag: 'div', rp_elmt_class: :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    assert_equal 'more text', @nkdoc.css('div.rp_ingredient_tag').first.inner_text
  end

  test 'initializing TextElmtData object from text element' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    anchor_elmt = text_element_containing 'line text'
    anchor_te = TextElmtData.new @nokotokens.elmt_bounds, anchor_elmt
    assert_equal anchor_elmt, anchor_te.elmt_bounds[anchor_te.elmt_bounds_index].first
  end

  test 'bringing outlying text under existing node' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 5, @nokotokens.count, tag: :div, rp_elmt_class: :rp_ingline
    assert_equal 1, @nkdoc.css('div.rp_ingline').count
    assert_equal 'line text outside line this is', @nkdoc.css('div.rp_ingline').inner_text.split.join(' ')

    # Go again prefixing the :rp_ingline node with the prefatory text
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 1, 7, tag: :div, rp_elmt_class: :rp_ingline
    assert_equal 1, @nkdoc.css('div.rp_ingline').count
    assert_equal 'some prefatory text line text', @nkdoc.css('div.rp_ingline').inner_text.split.join(' ')
  end

  test 'build a simple node from a single text element' do
    # Enclose the entire element
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 8, 12, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    @nkdoc.css('div.rp_ingredient_tag').first == newtree
    assert_equal 'outside line this is', @nkdoc.css('div.rp_ingredient_tag').inner_text.split.join(' ')

    # Enclose from beginning to middle
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 8, 10, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    @nkdoc.css('div.rp_ingredient_tag').first == newtree
    assert_equal 'outside line', @nkdoc.css('div.rp_ingredient_tag').inner_text.split.join(' ')

    # Enclose from middle to end
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 10, 12, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    @nkdoc.css('div.rp_ingredient_tag').first == newtree
    assert_equal 'this is', @nkdoc.css('div.rp_ingredient_tag').inner_text.split.join(' ')

    # Enclose a substring
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 9, 11, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    @nkdoc.css('div.rp_ingredient_tag').first == newtree
    assert_equal 'line this', @nkdoc.css('div.rp_ingredient_tag').inner_text.split.join(' ')
  end

  test 'successfully tag an enclosing element from a single text element' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 5, 7, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    @nkdoc.css('div.rp_ingredient_tag').first == newtree
    assert_equal 'line text', @nkdoc.css('div.rp_ingredient_tag').inner_text.split.join(' ')
  end

  test 'add tokens to a tree embedded within the selection' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.2.html'
    newtree = @nokotokens.enclose_tokens 4, 21, :tag => :div, :rp_elmt_class => :rp_ingredient_tag
    assert_equal 1, @nkdoc.css('div.rp_ingredient_tag').count
    assert_equal newtree, @nkdoc.css('div.rp_ingredient_tag').first
    assert_equal 'text 0 text 1 text 2 text 3 text 4 text 5', @nkdoc.css('div.rp_ingredient_tag').inner_text.split.join(' ')
  end

  test 'move tokens outside a selected tree' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.2.html'
    newtree = @nokotokens.enclose_tokens 8, 17, :tag => :div, :rp_elmt_class => :rp_ingline
    assert_equal 1, @nkdoc.css('div.rp_ingline').count
    assert_equal newtree, @nkdoc.css('div.rp_ingline').first
    assert_equal '1 text 2 text 3 text', @nkdoc.css('div.rp_ingline').inner_text.split.join(' ')
  end

  test 'appropriately enclosing a text element' do
    # The document includes an 'rp_ingredient_tag' element within an :rp_ingline
    # Declaring the contents of the former to be an :rp_ingline, the existing enclosures should be removed
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.2.html'
    newtree = @nokotokens.enclose_tokens 10, 12, :tag => :div, :rp_elmt_class => :rp_ingline
    assert_equal 1, @nkdoc.css('div.rp_ingline').count
    assert_equal newtree, @nkdoc.css('div.rp_ingline').first
    assert_equal 'text 2', @nkdoc.css('div.rp_ingline').inner_text.split.join(' ')
  end
end
