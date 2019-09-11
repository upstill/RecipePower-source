require 'test_helper'
require 'scraping/seeker.rb'

class SeekerTest < ActiveSupport::TestCase
  test 'seeking null produces null' do
    scanner = StrScanner.new 'Fourscore and seven years ago'
    ns = NullSeeker.match scanner
    subsq_scanner = ns.rest
    assert_equal ns.head, scanner
    assert_equal 0, ns.head.pos
    assert_equal 1, subsq_scanner.pos
  end

  test 'null sequence' do
    scanner = StrScanner.new 'Fourscore and seven years ago'
    ns = NullSeeker.match scanner
    ns = NullSeeker.match ns.rest
    ns = NullSeeker.match ns.rest
    ns = NullSeeker.match ns.rest
    ns = NullSeeker.match ns.rest
    # After the string is consumed, the result should be nil
    refute ns.rest.more? # Stream should be exhausted
  end

  test 'find a number in a stream' do
    scanner = StrScanner.new 'Fourscore and seven years ago'
    assert_nil NumberSeeker.seek(scanner)
    scanner = StrScanner.new 'Fourscore and 7 years ago'
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 3, ns.rest.pos
    scanner = StrScanner.new 'Fourscore and 7 1/2 years ago'
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 4, ns.rest.pos
    scanner = StrScanner.new 'Fourscore and 7/2 years ago'
    ns = NumberSeeker.seek(scanner)
    assert_not_nil ns
    assert_equal 2, ns.head.pos
    assert_equal 3, ns.rest.pos
  end

  test 'check validity of NullSeeker results' do
    scanner = StrScanner.new 'Fourscore and 7 years ago'
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
    scanner = StrScanner.new 'Fourscore and 7 1/2 years ago'
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
    scanner = StrScanner.new 'jalapeño peppers'
    ts = TagSeeker.match scanner, lex
    assert_not_empty ts.tag_ids
    assert_equal 1, ts.tag_ids.first
    refute ts.rest.more?
  end

  test 'match an amount' do
    lex = Lexaur.from_tags
    scanner = StrScanner.new 'fourscore and 1/2 cup ago'
    ts = AmountSeeker.seek scanner, lex
    assert ts
    assert ts.num
    assert ts.unit

    scanner = StrScanner.new 'fourscore and cup ago'
    ts = AmountSeeker.seek scanner, lex
    refute ts

    scanner = StrScanner.new 'fourscore and 1/2 ago'
    ts = AmountSeeker.seek scanner, lex
    assert ts
    assert ts.num
    refute ts.unit
  end

end