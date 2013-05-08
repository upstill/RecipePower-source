# encoding: UTF-8
require 'test_helper'
class ReferenceTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :tags

  test "Make New Reference" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = Reference.assert uri, jal
    rft = jal.primary_meaning
    refid = rft.id
    assert ref.referents.exists?(id: refid), "Referent wasn't added properly"
    assert_equal uri, ref.link.uri, "Link doesn't match reference"
  end
  
  test "Assert Redundant Reference Properly" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = Reference.assert uri, jal, :Tip
    assert_equal :Tip, ref.typesym, "Reference didn't get type"
    ref2 = Reference.assert uri, jal, :Video
    assert_equal :Video, ref2.typesym, "Reference didn't change type"
    assert_equal ref.id, ref2.id, "Asserting same uri and tag produced different references"
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
end