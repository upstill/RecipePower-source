require 'test_helper'
require 'scraping/lexaur.rb'
require 'scraping/scanner.rb'

class LexaurTest < ActiveSupport::TestCase
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
    scanner = StrScanner.new 'jalapeño' # Fail gracefully
    assert_nil lex.chunk(scanner)

    scanner = StrScanner.new 'jalapeño peppers'
    assert_not_nil lex.chunk(scanner) {|data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
      assert_nil stream.first
    }

    scanner = StrScanner.new 'jalapeño peppers, and more'
    assert_not_nil lex.chunk(scanner) { |data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
    }
  end

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
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
