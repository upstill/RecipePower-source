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
    newtree = assemble_tree_from_nodes ted, ted, :tag_or_node => :div, :classes => :rp_ingname
    # @nokotokens.enclose_by_text_elmt_data ted, ted, tag: 'div', classes: :rp_ingname
    assert_equal 1, @nkdoc.css('div.rp_ingname').count
    assert_equal 'more text', @nkdoc.css('div.rp_ingname').first.inner_text
  end

  test 'initializing TextElmtData object from text element' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    anchor_elmt = text_element_containing 'line text'
    anchor_te = TextElmtData.new @nokotokens, anchor_elmt
    assert_equal anchor_elmt, anchor_te.elmt_bounds[anchor_te.elmt_bounds_index].first
  end

  test 'bringing outlying text under existing node' do
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 5, @nokotokens.count, :tag => :div, :classes => :rp_ingline
    assert_equal 1, @nkdoc.css('div.rp_ingline').count
    assert_equal 'line text outside line this is', @nkdoc.css('div.rp_ingline').inner_text.split.join(' ')

    # Go again prefixing the :rp_ingline node with the prefatory text
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 1, 6, :tag => :div, :classes => :rp_ingline
    assert_equal 1, @nkdoc.css('div.rp_ingline').count
    assert_equal 'some prefatory text line text', @nkdoc.css('div.rp_ingline').inner_text.split.join(' ')
  end

  test 'build a simple node from a single text element' do
    # Enclose the entire element
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 8, 12, :tag => :div, :classes => :rp_ingname
    assert_equal 1, @nkdoc.css('div.rp_ingname').count
    @nkdoc.css('div.rp_ingname').first == newtree
    assert_equal 'outside line this is', @nkdoc.css('div.rp_ingname').inner_text.split.join(' ')

    # Enclose from beginning to middle
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 8, 10, :tag => :div, :classes => :rp_ingname
    assert_equal 1, @nkdoc.css('div.rp_ingname').count
    @nkdoc.css('div.rp_ingname').first == newtree
    assert_equal 'outside line', @nkdoc.css('div.rp_ingname').inner_text.split.join(' ')

    # Enclose from middle to end
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 10, 12, :tag => :div, :classes => :rp_ingname
    assert_equal 1, @nkdoc.css('div.rp_ingname').count
    @nkdoc.css('div.rp_ingname').first == newtree
    assert_equal 'this is', @nkdoc.css('div.rp_ingname').inner_text.split.join(' ')

    # Enclose a substring
    initialize_doc_from_file 'test/unit/scraping/noko_token_test_data.1.html'
    newtree = @nokotokens.enclose_tokens 9, 11, :tag => :div, :classes => :rp_ingname
    assert_equal 1, @nkdoc.css('div.rp_ingname').count
    @nkdoc.css('div.rp_ingname').first == newtree
    assert_equal 'line this', @nkdoc.css('div.rp_ingname').inner_text.split.join(' ')
  end

  test 'successfully tag an enclosing element from a single text element' do

  end
end