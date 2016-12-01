# encoding: UTF-8
require 'test_helper'
class ReferenceTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :tags

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

  test "Make New Reference" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = Reference.assert uri, jal
    ref.reload
    rft = jal.primary_meaning
    refid = rft.id
    assert ref.referents.exists?(id: refid), "Referent wasn't added properly"
  end
  
  test "Assert Redundant Reference Properly" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = Reference.assert uri, jal, :Tip
    assert_equal :Tip, ref.typesym, "Reference didn't get type"
    ref2 = Reference.assert uri, jal, :Video
    assert_equal :Video, ref2.typesym, "New reference on same url didn't get new type"
    assert_equal 1, ref2.referents.size, "Reference should have one referent"
  end
  
  test "Referent gets proper reference" do
    jal = tags(:jal)
    rft = Referent.express jal
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = Reference.assert uri, rft, :Definition
    assert_equal 16, ref.typenum, "Definition typenum not 16"
    assert (ref2 = rft.references.first), "Referent didn't get reference"
    assert_equal ref.id, ref2.id, "Referent's reference not ours"
    assert ref.referents.first, "New ref didn't get referent"
    assert_equal ref.referents.first.id, rft.id, "Reference's referent doesn't match"
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

  test "Reference types translate to classes" do
    assert_equal Reference.type_to_class(0), Reference
    assert_equal Reference.type_to_class(3), Reference
    assert_equal Reference.type_to_class(-3), Reference
    assert_equal Reference.type_to_class(12222), Reference
    assert_equal Reference.type_to_class(1), ArticleReference
    assert_equal Reference.type_to_class(2), NewsitemReference
    assert_equal Reference.type_to_class(4), TipReference
    assert_equal Reference.type_to_class(8), VideoReference
    assert_equal Reference.type_to_class(16), DefinitionReference
    assert_equal Reference.type_to_class(32), HomepageReference
    assert_equal Reference.type_to_class(64), ProductReference
    assert_equal Reference.type_to_class(128), OfferingReference
    assert_equal Reference.type_to_class(256), RecipeReference
    assert_equal Reference.type_to_class(512), ImageReference
    assert_equal Reference.type_to_class(1024), SiteReference
    assert_equal Reference.type_to_class(2048), EventReference
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
end