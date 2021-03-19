require 'test_helper'
require 'scraping/lexaur.rb'
require 'scraping/scanner.rb'

class LexaurTest < ActiveSupport::TestCase
  def setup
    @ingred_tags = %w{ ground\ turmeric ground\ cinnamon ground\ cumin lemon lemon\ juice garlic\ clove sea\ salt butter Dijon\ mustard capers marjoram black\ pepper Brussels\ sprouts white\ cauliflower Romanesco\ (green)\ cauliflower'}.
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
    str = 'lemon juice'
    result = lex.find str
    assert_not_empty result
  end

  test 'lexaur distribute' do
    lex = Lexaur.from_tags

    str = 'lemon juice'
    result = nil
    lex.distribute StrScanner.new(str) do |term_ids, start_stream, end_stream|
      refute end_stream.more?
      result = Tag.where(id: term_ids).first
    end
    assert_not_nil result
    assert_equal str, result.name

    str = 'sea salt and black pepper'
    results, past = [], nil
    lex.distribute(StrScanner.new(str)) { |term_ids| results << Tag.where(id: term_ids).first }
    assert_not_empty results
    assert_equal 'sea salt', results.last.name
    assert_equal 'black pepper', results.first.name

    # Distribute initial substring of antecedent to successor
    str = 'ground cinnamon and nutmeg'
    results = []
    lex.distribute(StrScanner.new(str)) { |term_ids| results << Tag.where(id: term_ids).first }
    assert_not_empty results
    assert_equal 'ground cinnamon', results.last.name
    assert_equal 'ground nutmeg', results.first.name

    # Distribute terminal substring of successor to antecedent
    str = 'instant or active dry yeast'
    results = []
    lex.distribute(StrScanner.new(str)) { |term_ids| results << Tag.where(id: term_ids).first }
    assert_not_empty results
    assert_equal 'instant dry yeast', results.last.name
    assert_equal 'active dry yeast', results.first.name
  end

  test 'lexaur chunks simple stream' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new'jalapeño' # Fail gracefully
    assert_nil lex.chunk(scanner)

    scanner = StrScanner.new 'jalapeño peppers'
    lex.chunk(scanner) do |data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
      assert_nil stream.first
    end

    scanner = StrScanner.new 'jalapeño peppers, and more'
    lex.chunk(scanner) { |data, stream|
      assert_not_nil data
      assert_includes data, 1
      assert_equal 2, stream.pos
    }
  end

  # Test whether the lex finds the given string, and consumes the entire string
  def assert_finds_tag lex, string
    scanner = StrScanner.new string
    tag_ids = nil
    lex.chunk(scanner) { |data, stream|
      assert_not_nil data
      tag_ids = data
      assert_empty stream.to_s
    }
    tag = Tag.by_string(string).first
    assert_not_nil tag_ids, "Lexaur didn't find any tag by searching for '#{string}'; should have found '#{tag.name}'/'#{tag.normalized_name}'"
    assert_includes tag_ids, tag.id, "Found tag '#{tag.name}'/'#{tag.normalized_name}' doesn't match search on '#{string}'"
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

  test 'Lexaur correctly resolves long name on appropriate datatype' do
    Tag.assert 'chopped', :Condition
    Tag.assert 'chopped almonds', :Ingredient
    Tag.assert 'chopped walnuts', :Ingredient
    Tag.assert 'almonds', :Ingredient
    Tag.assert 'walnuts', :Ingredient
    lex = Lexaur.from_tags
    scanner = StrScanner.new 'chopped'
    # result = lex.chunk scanner do |terms, onward|
    result = nil
    lex.distribute scanner do |terms, start_stream, end_stream, operand|
      result = Tag.where(id: terms, tagtype: Tag.typenum(:Condition)).first
    end
    assert_equal result.class, Tag
    assert_equal 'chopped', result.name

    scanner = StrScanner.new 'chopped almonds or walnuts'
    tags = []
    # lex.match_list scanner do |terms, onward|
    lex.distribute scanner do |terms, start_stream, end_stream, operand|
      tags << Tag.where(id: terms, tagtype: Tag.typenum(:Ingredient)).first
      tags.last
    end
    assert_equal 2, tags.count
    assert_equal ['chopped walnuts', 'chopped almonds'], tags.map(&:name)
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

  test 'Lexaur correctly handles bogus list' do
    lex = Lexaur.from_tags
    string = 'ground cinnamon, woody ends trimmed'
    found_tag = nil
    lex.distribute(StrScanner.new(string)) do |terms, start_stream, end_stream, operand|
      assert_not_nil terms&.first
      assert_equal 'ground cinnamon', (found_tag = Tag.find_by(id: terms.first).name)
    end
    assert_not_nil found_tag, "Didn't find 'ground cinnamon' in '#{string}'"
    assert_equal 'ground cinnamon', found_tag, "Found '#{found_tag}' in '#{string}'"
  end

  test 'Lexaur parses lists of tags' do
    lex = Lexaur.from_tags
    strings = %w{ ground\ turmeric ground\ cumin ground\ cinnamon }  # Expect to find
    # lex.match_list(StrScanner.new('ground turmeric, cumin and cinnamon')) do |terms, stream|
    lex.distribute(StrScanner.new('ground turmeric, cumin and cinnamon')) do |terms, start_stream, end_stream, operand|
      found = Tag.find(terms.first).name
      assert (strings.delete found), "Didn't match #{found}"
    end
    assert_empty strings, "Strings not found: #{strings}"

    strings = %w{ ground\ turmeric ground\ cumin ground\ cinnamon }
    # lex.match_list(StrScanner.new('ground turmeric, cumin or ground cinnamon')) do |terms, stream|
    lex.distribute(StrScanner.new('ground turmeric, cumin or ground cinnamon')) do |terms, start_stream, end_stream, operand|
      found = Tag.find(terms.first).name
      assert (strings.delete found), "Didn't match #{found}"
    end
    assert_empty strings, "Strings not found: #{strings}"

    strings = %w{ yellow\ miso\ paste red\ miso\ paste }
    # lex.match_list(StrScanner.new('yellow or red miso paste')) do |terms, stream|
    lex.distribute(StrScanner.new('yellow or red miso paste')) do |terms, start_stream, end_stream, operand|
      found = Tag.find(terms.first).name
      assert (strings.delete found), "Didn't match #{found}"
    end
    assert_empty strings, "Strings not found: #{strings}"
  end

  test 'Lexaur handles interrupted multitoken tag' do
    lex = Lexaur.from_tags
    strings = %w{ ground\ turmeric ground\ cumin ground\ cinnamon }
    skipper = -> (stream){
      stream.peek == 'to_skip' ? stream.rest : stream
    }
    # lex.match_list(StrScanner.new('ground to_skip turmeric'), skipper: skipper) do |terms, stream|
    lex.distribute(StrScanner.new('ground to_skip turmeric'), skipper: skipper) do |terms|
      target = strings.shift
      assert_equal target, Tag.find(terms.first).name, "Didn't match #{target}"
    end
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end
end
