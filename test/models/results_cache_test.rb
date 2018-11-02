require 'test_helper'

class ResultsCacheTest < ActiveSupport::TestCase

  test "It saves and restores parameters" do
    vid = users(:thing1).id
    rc = IntegersCache.retrieve_or_build "abcde", ['integers'], viewerid: vid, random: "random"
    rc = rc.first
    # :viewerid param is retained b/c it's in the params_needed list
    assert_equal vid, rc.param(:viewerid)
    # :random, on the other hand, is not
    assert_nil rc.param(:random)

    rc = UserFeedsCache.retrieve_or_build "abcde", ['integers'], viewerid: vid, org: :posted
    rc = rc.first
    assert_equal vid, rc.param(:viewerid)
    assert_equal :posted, rc.param(:org)
  end
end
