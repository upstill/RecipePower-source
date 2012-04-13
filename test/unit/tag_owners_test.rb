require 'test_helper'
class TagOwnershipTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :users
    
    # Admitting user for tag that's already global has no effect
    
    # Admitting invalid user for global tag has no effect
    
    # Admitting invalid user for non-global tag fails
    
    # Admitting valid user for non-global tag succeeds
    
    # Non-global tag invisible to user before admitted
    
    # Tag visible to user after admitting
    
    # Private tag is invisible to other users
    
    # Private tag is available to owner(s)

    # New tag made non-global, visible to user when asserted by user
    
    # Folded assertion by user to non-global tag makes it visible to user
    
    # User added to tag's list when user asserts an existing key
    
    # Tag made global when asserted by super
    test "super-user makes global tags" do
        superid = users(:super).id
        thing2id = users(:thing2).id
        assert Tag.assert_tag("random tag", userid: superid).isGlobal
        assert Tag.strmatch("random tag", userid: thing2id ).first
    end
    
    # Non-global tags accessible for user super
    test "super-user sees all non-global tags" do
        superid = users(:super).id
        thing1id = users(:thing1).id
        thing2id = users(:thing2).id
        assert !Tag.assert_tag("thing1 tag", userid: thing1id).isGlobal
        assert_nil Tag.strmatch("thing1 tag", userid: thing2id, matchall: true).first
        assert Tag.strmatch("thing1 tag", userid: superid).first
        assert Tag.strmatch("thing1 tag").first
    end
end