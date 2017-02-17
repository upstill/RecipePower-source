# encoding: UTF-8
require 'test_helper'
class ReferenceTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :tags
=begin
  test "querify skipping protocol" do
    q, urls = Reference.querify 'http://ganga.com/upchuck', true
    assert_equal ['http://ganga.com/upchuck%' ], urls
    assert_equal '"references"."url" ILIKE ?', q
    q, urls = Reference.querify ['https://ganga.com/upchuck'], true
    assert_equal ['https://ganga.com/upchuck%' ], urls
    assert_equal '"references"."url" ILIKE ?', q
    q, urls = Reference.querify [ 'http://ganga.com/upchuck', 'http://ganga.com' ], true
    assert_equal ['http://ganga.com/%' ], urls
    assert_equal '"references"."url" ILIKE ?', q
    q, urls = Reference.querify [ 'http://ganga.com/upchuck', 'https://ganga.com' ], true
    assert_equal ['http://ganga.com/upchuck%', 'https://ganga.com/%' ], urls
    assert_equal '"references"."url" ILIKE ? OR "references"."url" ILIKE ?', q
  end

  test "querify including protocol" do
    q, urls = Reference.querify 'http://ganga.com/upchuck'
    assert_equal ['http://ganga.com/upchuck', 'https://ganga.com/upchuck' ], urls
    assert_equal "\"references\".\"url\" in (?, ?)", q
    q, urls = Reference.querify ['https://ganga.com/upchuck']
    assert_equal ['http://ganga.com/upchuck', 'https://ganga.com/upchuck' ], urls
    assert_equal "\"references\".\"url\" in (?, ?)", q
    q, urls = Reference.querify [ 'http://ganga.com/upchuck', 'https://ganga.com' ]
    assert_equal ['http://ganga.com/upchuck', 'https://ganga.com/upchuck', 'http://ganga.com/', 'https://ganga.com/' ], urls
    assert_equal "\"references\".\"url\" in (?, ?, ?, ?)", q

    # Minimizes duplicates
    q, urls = Reference.querify [ 'http://ganga.com/upchuck', 'https://ganga.com/upchuck', 'http://ganga.com/', 'https://ganga.com/' ]
    assert_equal ['http://ganga.com/upchuck', 'https://ganga.com/upchuck', 'http://ganga.com/', 'https://ganga.com/' ], urls
    assert_equal "\"references\".\"url\" in (?, ?, ?, ?)", q
  end

  test "bogus urls" do
    q, urls = Reference.querify 'bogus url'
    assert_equal [ ], urls
    assert_equal '', q
    q, urls = Reference.querify [ 'bogus url' ]
    assert_equal [ ], urls
    assert_equal '', q
    q, urls = Reference.querify [ 'bogus url', 'another bogus' ]
    assert_equal [ ], urls
    assert_equal '', q
    q, urls = Reference.querify 'bogus url', true
    assert_equal [ ], urls
    assert_equal '', q
    q, urls = Reference.querify [ 'bogus url' ], true
    assert_equal [ ], urls
    assert_equal '', q
    q, urls = Reference.querify [ 'bogus url', 'another bogus' ], true
    assert_equal [ ], urls
    assert_equal '', q
  end

  test "References know their typenums" do
    assert_equal 0, Reference.new.typenum
    assert_equal 1, ArticleReference.new.typenum
    assert_equal 2, NewsitemReference.new.typenum
    assert_equal 4, TipReference.new.typenum
    assert_equal 8, VideoReference.new.typenum
    assert_equal 16, DefinitionReference.new.typenum
    assert_equal 32, HomepageReference.new.typenum
    assert_equal 64, ProductReference.new.typenum
    assert_equal 128, OfferingReference.new.typenum
    assert_equal 256, RecipeReference.new.typenum
    assert_equal 512, ImageReference.new.typenum
    assert_equal 1024, SiteReference.new.typenum
    assert_equal 2048, EventReference.new.typenum
  end

  test "Site References aren't redundant" do
    sr1 = SiteReference.find_or_initialize 'http://esquire.com/bijou'
    sr1.map &:save
    sr2 = SiteReference.find_or_initialize 'https://esquire.com/bijou'
    sr2.each { |sr| assert sr1.include?(sr) }
    sr2 = SiteReference.find_or_initialize 'https://esquire.com'
    sr2.each { |sr| assert sr1.include?(sr) }
    sr2 = SiteReference.find_or_initialize 'https://esquire.com/'
    sr2.each { |sr| assert sr1.include?(sr) }
  end
=end
end