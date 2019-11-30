require 'test_helper'
require 'scraping/seeker.rb'

class SeekerTest < ActiveSupport::TestCase
  test 'seeking null produces null' do
    scanner = StrScanner.from_string "Fourscore and seven years ago"
    ns = NullSeeker.match scanner
    subsq_scanner = ns.rest
    assert_equal ns.head, scanner
    assert_equal 0, ns.head.pos
    assert_equal 1, subsq_scanner.pos
  end

  test 'null sequence' do
    scanner = StrScanner.from_string "Fourscore and seven years ago "
    ns = NullSeeker.match scanner
    ns = NullSeeker.match ns.rest
    ns = NullSeeker.match ns.rest
    ns = NullSeeker.match ns.rest
    ns = NullSeeker.match ns.rest
    # After the string is consumed, the result should be nil
    refute ns.rest.more? # Stream should be exhausted
  end

  test 'find a number in a stream' do
    scanner = StrScanner.from_string "Fourscore and seven years ago "
    assert_nil NumberSeeker.seek(scanner)
    scanner = StrScanner.from_string "Fourscore and 7 years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 3, ns.rest.pos
    scanner = StrScanner.from_string "Fourscore and 7 1/2 years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 4, ns.rest.pos
    scanner = StrScanner.from_string "Fourscore and 7/2 years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 3, ns.rest.pos
    scanner = StrScanner.from_string "Fourscore and ⅐ years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 3, ns.rest.pos
    scanner = StrScanner.from_string "Fourscore and 7⅐ years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 3, ns.rest.pos
    scanner = StrScanner.from_string "Fourscore and 7 ⅐ years ago "
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 4, ns.rest.pos
  end

  test 'check validity of NullSeeker results' do
    scanner = StrScanner.from_string "Fourscore and 7 years ago "
    results = []
    pos = 0
    while ns = NullSeeker.match(scanner)
      assert_equal pos, scanner.pos
      pos += 1
      assert_equal ns.head, scanner
      results << ns
      break unless (scanner = ns.rest).more?
      assert_equal (ns.head.pos+1), ns.rest.pos
    end
    assert_equal 5, results.count
    assert_equal NullSeeker, results.first.class
    assert_equal NullSeeker, results.last.class
  end

  test 'scan a string that includes a number' do
    scanner = StrScanner.from_string "Fourscore and 7 1/2 years ago "
    results = []
    while scanner.more? && (ns = NumberSeeker.match(scanner) || NullSeeker.match(scanner))
      results << ns
      scanner = ns.rest
    end
    assert_equal 5, results.count
    assert_equal NumberSeeker, results[2].class
  end

  test 'scan a string with an embedded tag' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('jalapeño peppers')
    ts = TagSeeker.match scanner, lex
    assert_not_empty ts.tag_ids
    assert_equal 1, ts.tag_ids.first
    refute ts.rest.more?
  end

  test 'match an amount' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('fourscore and 1/2 cup ago')
    ts = AmountSeeker.seek scanner, lex
    assert ts
    assert ts.num
    assert ts.unit

    scanner = StrScanner.from_string('fourscore and cup ago')
    ts = AmountSeeker.seek scanner, lex
    refute ts

    scanner = StrScanner.from_string('fourscore and 1/2 ago')
    ts = AmountSeeker.seek scanner, lex
    assert ts
    assert ts.num
    refute ts.unit
  end

  test 'match a single condition' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('peeled')
    cs = ConditionsSeeker.match scanner, lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 1, cs.tag_seekers.count
    assert_equal 0, cs.head.pos
    assert_equal 1, cs.rest.pos
    scanner = StrScanner.from_string('1/2 cup peeled tomatoes')
    cs = ConditionsSeeker.seek scanner, lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.tag_seekers.first
    assert_equal 1, cs.tag_seekers.count
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.head.pos
    assert_equal 3, cs.rest.pos
  end

  test 'match two conditions joined with and' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('peeled and seeded')
    cs = ConditionsSeeker.match scanner, lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.tag_seekers.count
    assert_equal 0, cs.head.pos
    assert_equal 3, cs.rest.pos

    scanner = StrScanner.from_string('1/2 cup peeled and seeded tomatoes')
    cs = ConditionsSeeker.seek scanner, lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.tag_seekers.count
    assert_equal 2, cs.head.pos
    assert_equal 5, cs.rest.pos
  end

  test 'match a series of three conditions' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('peeled, seeded and chopped')
    cs = ConditionsSeeker.match scanner, lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.tag_seekers.count
    assert_equal 0, cs.head.pos
    assert_equal 5, cs.rest.pos

    scanner = StrScanner.from_string('1/2 cup peeled, seeded and chopped tomatoes')
    cs = ConditionsSeeker.seek scanner, lex
    assert_not_nil cs
    assert_instance_of ConditionsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.tag_seekers.count
    assert_equal 2, cs.head.pos
    assert_equal 7, cs.rest.pos
  end

  test 'match a series of two ingredients' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('chili bean and jalapeño peppers')
    cs = IngredientsSeeker.seek scanner, lex
    assert_not_nil cs
    assert_instance_of IngredientsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 2, cs.tag_seekers.count
    assert_equal 0, cs.head.pos
    assert_equal 5, cs.rest.pos
  end

  test 'match a series of three ingredients' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('chili bean, cilantro and jalapeño peppers')
    cs = IngredientsSeeker.seek scanner, lex
    assert_not_nil cs
    assert_instance_of IngredientsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.tag_seekers.count
    assert_equal 0, cs.head.pos
    assert_equal 7, cs.rest.pos
  end

  test 'match a series of three ingredients embedded in noise' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('1/2 cup sifted chili bean, cilantro and jalapeño peppers -- refined')
    cs = IngredientsSeeker.seek scanner, lex
    assert_not_nil cs
    assert_instance_of IngredientsSeeker, cs
    ts = cs.tag_seekers.first
    assert_instance_of TagSeeker, ts
    assert_equal 3, cs.tag_seekers.count
    assert_equal 3, cs.head.pos
    assert_equal 10, cs.rest.pos
  end

  test 'recognize a full ingredient spec' do
    lex = Lexaur.from_tags
    scanner = StrScanner.from_string('cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_nil ils.amount
    assert_nil ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 1, ils.rest.pos

    scanner = StrScanner.from_string('peeled, seeded and chopped cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_nil ils.amount
    assert_instance_of ConditionsSeeker, ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 6, ils.rest.pos

    scanner = StrScanner.from_string('1/2 cup cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_instance_of AmountSeeker, ils.amount
    assert_nil ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 3, ils.rest.pos

    scanner = StrScanner.from_string('1/2 cup  peeled, seeded and chopped cilantro sifted chili bean, cilantro and jalapeño peppers -- refined')
    ils = IngredientSpecSeeker.seek scanner, lex
    assert_not_nil ils
    assert_instance_of IngredientSpecSeeker, ils
    assert_instance_of AmountSeeker, ils.amount
    assert_instance_of ConditionsSeeker, ils.condits
    assert_instance_of IngredientsSeeker, ils.ingreds
    assert_equal 8, ils.rest.pos
  end

end
