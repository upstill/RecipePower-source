require 'test_helper'
require 'scraping/lexaur.rb'
require 'scraping/scanner.rb'

class LexaurTest < ActiveSupport::TestCase
  def setup
    @ingred_tags = %w{ lemon lemon\ juice garlic\ clove sea\ salt butter Dijon\ mustard capers marjoram black\ pepper Brussels\ sprouts white\ cauliflower Romanesco\ (green)\ cauliflower'}.
        each { |name| Tag.assert name, :Ingredient }
    @unit_tags = %w{ tablespoon teaspoon cup pound lb small\ head clove }.
        each { |name| Tag.assert name, :Unit }
    @process_tags = %w{ chopped softened rinsed }.
        each { |name| Tag.assert name, :Unit }
  end

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

  test 'lexaur finds longer tag' do
    lex = Lexaur.from_tags
    result = lex.find('lemon juice')
    assert_not_empty result
  end

  test 'lexaur chunks simple stream' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string'jalapeño' # Fail gracefully
    assert_nil lex.chunk(scanner)

    scanner = StrScanner.from_string 'jalapeño peppers'
    lex.chunk(scanner) {|data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
      assert_nil stream.first
    }

    scanner = StrScanner.from_string 'jalapeño peppers, and more'
    assert_not_nil lex.chunk(scanner) { |data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
    }
  end

  # Test whether the lex finds the given string, and consumes the entire string
  def assert_finds_tag lex, string
    scanner = StrScanner.from_string string
    tag_id = nil
    lex.chunk(scanner) { |data, stream|
      assert_not_nil data
      tag_id = data
      assert_empty stream.rest.to_s
    }
    tag = Tag.by_string(string).first
    assert_not_nil tag_id, "Lexaur didn't find any tag by searching for '#{string}'; should have found '#{tag.name}'/'#{tag.normalized_name}'"
    assert_equal tag.id, tag_id.first, "Found tag '#{tag.name}'/'#{tag.normalized_name}' doesn't match search on '#{string}'"
  end

  test 'Lexaur handles two tags with the same normalized name' do
    Tag.assert 'tsp.', :Unit
    assert_equal Tag.by_string('tsp'), Tag.by_string('Tsp.')

    lex = Lexaur.from_tags
    assert_finds_tag(lex, 'Tsp.')
    assert_finds_tag(lex, 'tsp')
  end

  test 'Lexaur elides punctuation not seen in normalized_name' do
    Tag.assert 'lb', :Unit
    assert_equal Tag.by_string('lb'), Tag.by_string('lb.')

    lex = Lexaur.from_tags
    assert_finds_tag(lex, 'lb.')
    assert_finds_tag(lex, 'lb')
  end

  test 'Lexaur manages tokens with embedded dash correctly' do
    Tag.assert 'a silly god damned tag', :Unit
    assert_equal Tag.by_string('a silly god-damned tag'), Tag.by_string('a silly god damned tag')
    Tag.assert 'another silly god damned tag', :Unit
    assert_equal Tag.by_string('another silly god-damned tag'), Tag.by_string('another silly god damned tag')

    lex = Lexaur.from_tags
    assert_finds_tag(lex, 'a silly god-damned tag')
    assert_finds_tag(lex, 'a silly god damned tag')
    assert_finds_tag(lex, 'another silly god-damned tag')
    assert_finds_tag(lex, 'another silly god damned tag')
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end
end
