require 'test_helper'
require 'scraping/seeker.rb'

class SeekerTest < ActiveSupport::TestCase
  test 'seeking null produces null' do
    scanner = StrScanner.new "Fourscore and seven years ago"
    ns = NullSeeker.match scanner
    subsq_scanner = ns.tail_stream
    assert_equal ns.head_stream, scanner
    assert_equal 0, ns.head_stream.pos
    assert_equal 1, subsq_scanner.pos
  end

  test 'null sequence' do
    scanner = StrScanner.new "Fourscore and seven years ago "
    ns = NullSeeker.match scanner
    ns = NullSeeker.match ns.tail_stream
    ns = NullSeeker.match ns.tail_stream
    ns = NullSeeker.match ns.tail_stream
    ns = NullSeeker.match ns.tail_stream
    # After the string is consumed, the result should be nil
    refute ns.tail_stream.more? # Stream should be exhausted
  end

  test 'find a number in a stream' do
    scanner = StrScanner.new "Fourscore and seven years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 3, ns.tail_stream.pos
    scanner = StrScanner.new "Fourscore and 7 years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 3, ns.tail_stream.pos
    scanner = StrScanner.new "Fourscore and 7 1/2 years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 4, ns.tail_stream.pos
    scanner = StrScanner.new "Fourscore and 7/2 years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 3, ns.tail_stream.pos
    scanner = StrScanner.new "Fourscore and ⅐ years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 3, ns.tail_stream.pos
    scanner = StrScanner.new "Fourscore and 7⅐ years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 3, ns.tail_stream.pos
    scanner = StrScanner.new "Fourscore and 7 ⅐ years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head_stream.pos
    assert_equal 4, ns.tail_stream.pos
  end

  test 'check validity of NullSeeker results' do
    scanner = StrScanner.new "Fourscore and 7 years ago "
    results = []
    pos = 0
    while ns = NullSeeker.match(scanner)
      assert_equal pos, scanner.pos
      pos += 1
      assert_equal ns.head_stream, scanner
      results << ns
      break unless (scanner = ns.tail_stream).more?
      assert_equal (ns.head_stream.pos+1), ns.tail_stream.pos
    end
    assert_equal 5, results.count
    assert_equal NullSeeker, results.first.class
    assert_equal NullSeeker, results.last.class
  end

  test 'scan a string that includes a number' do
    scanner = StrScanner.new "Fourscore and 7 1/2 years ago "
    results = []
    while scanner.more? && (ns = NumberSeeker.match(scanner) || NullSeeker.match(scanner))
      results << ns
      scanner = ns.tail_stream
    end
    assert_equal 5, results.count
    assert_equal NumberSeeker, results[2].class
  end

  test 'scan a string with an embedded tag' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('jalapeño peppers')
    ts = TagSeeker.match scanner, lexaur: lex
    assert_not_empty ts.tagdata
    assert_equal 1, ts.tagdata[:id]
    refute ts.tail_stream.more?
  end

  test 'match an amount' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('fourscore and 1/2 cup ago')
    ts = AmountSeeker.seek scanner, lexaur: lex
    assert ts
    assert ts.num
    assert ts.unit

    scanner = StrScanner.new('fourscore and cup ago')
    ts = AmountSeeker.seek scanner, lexaur: lex
    assert_equal 'cup', ts.unit.to_s

    scanner = StrScanner.new('fourscore and 1/2 ago')
    ts = AmountSeeker.seek scanner, lexaur: lex
    assert ts
    assert ts.num
    refute ts.unit
  end

  test 'match a single condition' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('peeled')
    cs = ConditionsSeeker.match scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 1, cs.children.count
    assert_equal 0, cs.head_stream.pos
    assert_equal 1, cs.tail_stream.pos
    scanner = StrScanner.new('1/2 cup peeled tomatoes')
    cs = ConditionsSeeker.seek scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.children.first
    assert_equal 1, cs.children.count
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.head_stream.pos
    assert_equal 3, cs.tail_stream.pos
  end

  test 'match two conditions joined with and' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('peeled and seeded')
    cs = ConditionsSeeker.match scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.children.count
    assert_equal 0, cs.head_stream.pos
    assert_equal 3, cs.tail_stream.pos

    scanner = StrScanner.new('1/2 cup peeled and seeded tomatoes')
    cs = ConditionsSeeker.seek scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.children.count
    assert_equal 2, cs.head_stream.pos
    assert_equal 5, cs.tail_stream.pos
  end

  test 'match a series of three conditions' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('peeled, seeded and chopped')
    cs = ConditionsSeeker.match scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.children.count
    assert_equal 0, cs.head_stream.pos
    assert_equal 5, cs.tail_stream.pos

    scanner = StrScanner.new('1/2 cup peeled, seeded and chopped tomatoes')
    cs = ConditionsSeeker.seek scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.children.count
    assert_equal 2, cs.head_stream.pos
    assert_equal 7, cs.tail_stream.pos
  end

  test 'match a series of two ingredients' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('chili bean and jalapeño peppers')
    cs = IngredientsSeeker.seek scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of IngredientsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.children.count
    assert_equal 0, cs.head_stream.pos
    assert_equal 5, cs.tail_stream.pos
  end

  test 'match a series of three ingredients' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('chili bean, cilantro and jalapeño peppers')
    cs = IngredientsSeeker.seek scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of IngredientsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.children.count
    assert_equal 0, cs.head_stream.pos
    assert_equal 7, cs.tail_stream.pos
  end

  test 'match a series of three ingredients embedded in noise' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('1/2 cup sifted chili bean, cilantro and jalapeño peppers -- refined')
    cs = IngredientsSeeker.seek scanner, lexaur: lex
    assert_not_nil cs
    assert_instance_of IngredientsSeeker, cs
    ts = cs.children.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.children.count
    assert_equal 3, cs.head_stream.pos
    assert_equal 10, cs.tail_stream.pos
  end

  test 'recognize a full ingredient spec' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new('cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lexaur: lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_nil ils.amount
    assert_nil ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 1, ils.tail_stream.pos

    scanner = StrScanner.new('peeled, seeded and chopped cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lexaur: lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_nil ils.amount
    assert_instance_of ConditionsSeeker, ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 6, ils.tail_stream.pos

    scanner = StrScanner.new('1/2 cup cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lexaur: lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_instance_of AmountSeeker, ils.amount
    assert_nil ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 3, ils.tail_stream.pos

    scanner = StrScanner.new('1/2 cup  peeled, seeded and chopped cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lexaur: lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_instance_of AmountSeeker, ils.amount
    assert_instance_of ConditionsSeeker, ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 8, ils.tail_stream.pos
  end

  test 'parenthetical seeker' do
    scanner = StrScanner.new "Here's ( a parenthetical thought) and the rest of it "
    assert_nil ParentheticalSeeker.match(scanner)
    scanner = scanner.rest
    after = ParentheticalSeeker.match(scanner) do |inside|
      assert_equal 'a parenthetical thought', inside.to_s
    end
    assert_equal 'and the rest of it', after.to_s

    scanner = StrScanner.new "Here's ( a (doubly) parenthetical thought) and the rest of it "
    assert_nil ParentheticalSeeker.match(scanner)
    scanner = scanner.rest
    after = ParentheticalSeeker.match(scanner) do |inside|
      assert_equal 'a ( doubly ) parenthetical thought', inside.to_s
    end
    assert_equal 'and the rest of it', after.to_s
  end

end
