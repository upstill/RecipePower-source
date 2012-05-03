# encoding: UTF-8
require 'test_helper'
class ReferentTest < ActiveSupport::TestCase 
    fixtures :referents
    
    test "parent-child relation established" do
        r1 = Referent.create
        r2 = Referent.create
        r1.children << r2
        assert_equal 1, r1.child_ids.count, "Added child, but no child_ids"
        assert_equal 1, r2.parent_ids.count, "Added child, but child doesn't list parent"
    end
    
end