require 'test_helper'
class TagOwnershipTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :users
    
    # Admitting user for tag that's already global has no effect
    test "Admitting user for global tag is redundant" do
        superid = users(:super).id
        thing2id = users(:thing2).id
        t = Tag.assert_tag("global tag", userid: superid)
        assert t.isGlobal, "Tag asserted by super isn't global"
        assert_equal t, Tag.assert_tag(t, userid: thing2id ), "Reasserting tag for new user makes new tag"
        assert t.isGlobal, "Tag asserted by thing2 is no longer global"
        assert ! t.owner_ids.include?(thing2id), "User asserted for global tag added to list"
        assert_equal t, Tag.assert_tag(t, userid: -1 ), "Reasserting tag for invalid user makes new tag"
        assert t.isGlobal, "Tag asserted by invalid user is no longer global"
        assert ! t.owner_ids.include?(-1), "Invalid user asserted for global tag added to list"
    end
    
    # Admitting invalid user for non-global tag fails
    test "Admitting invalid user for local tag has no effect" do
        thing1id = users(:thing1).id
        t = Tag.assert_tag("local tag", userid: thing1id)
        assert_nil t.isGlobal, "Local tag for specific user turned up global"
        assert_equal [thing1id], t.owner_ids, "Owner ids for local tag is wrong"
        assert_equal t, Tag.assert_tag(t, userid: -1 ), "Reasserting tag for invalid user makes new tag"
        assert_equal [thing1id], t.owner_ids, "Asserting invalid user on tag changes owners"
        assert_nil t.isGlobal, "Asserting invalid owner on local tag made it global"
    end
    
    # Admitting valid user for non-global tag succeeds
    test "Admitting valid user to local tag succeeds" do
        thing1id = users(:thing1).id
        tagstr = "co-owned local tag"
        assert_nil Tag.strmatch(tagstr, userid: thing1id).first, "Co-owned local tag shouldn't match before asserting"
        # Asserting local tag, owned by thing1
        t = Tag.assert_tag(tagstr, userid: thing1id)
        # Check that it's indeed local
        assert_nil t.isGlobal, "co-owned local tag for specific user turned up global"
        # Check that thing1 can see it
        assert Tag.strmatch(tagstr, userid: thing1id).first, "Can't find co-owned local tag on creator"
        # Check that thing2 can't see it
        thing2id = users(:thing2).id
        assert_nil Tag.strmatch(tagstr, userid: thing2id).first, "New local tag should be invisible to other user"
        # Now assert it for thing2
        assert_equal t, Tag.assert_tag(t, userid: thing2id ), "Reasserting local tag for new, valid user makes new tag"
        # Make sure thing2 appears among tag owners
        assert t.owner_ids.include?(thing2id), "New user for local tag doesn't appear"
        # Make sure thing2 can now see it
        assert Tag.strmatch(tagstr, userid: thing2id).first, "Can't find co-owned local tag on new user"
    end

    test "New tag made non-global, visible to user when asserted by user" do
        thing1id = users(:thing1).id
        tagstr = "co-owned local tag"
        assert_nil Tag.strmatch(tagstr, userid: thing1id).first, "Co-owned local tag shouldn't match before asserting"
        # Asserting local tag, owned by thing1
        t = Tag.assert_tag(tagstr, userid: thing1id)
        # Check that it's indeed local
        assert_nil t.isGlobal, "co-owned local tag for specific user turned up global"
        # Check that thing1 can see it
        t = Tag.strmatch(tagstr, userid: thing1id).first
        assert t, "Can't find co-owned local tag on creator"
        # Check that unspecified user can't see it
        assert_nil Tag.strmatch(tagstr).first, "Local tag should be invisible unless user specified"
        # Check that thing2 can't see it
        thing2id = users(:thing2).id
        assert_nil Tag.strmatch(tagstr, userid: thing2id).first, "New local tag should be invisible to other user"
        # Admit user directly, rather than by assert_tag
        t.admit_user thing2id
        # Make sure thing2 appears among tag owners
        assert t.owner_ids.include?(thing2id), "New user for local tag doesn't appear"
        # Make sure thing2 can now see it
        assert Tag.strmatch(tagstr, userid: thing2id).first, "Can't find co-owned local tag on new user"
    end
    
    # Tag made global when asserted by super
    test "super-user makes global tags" do
        superid = users(:super).id
        thing2id = users(:thing2).id
        assert Tag.assert_tag("random tag", userid: superid).isGlobal
        assert Tag.strmatch("random tag", userid: thing2id ).first
    end
    
    # Non-global tags accessible for user super and nil user
    test "super-user sees all non-global tags" do
        superid = users(:super).id
        thing1id = users(:thing1).id
        thing2id = users(:thing2).id
        assert !Tag.assert_tag("thing1 tag", userid: thing1id).isGlobal
        assert_nil Tag.strmatch("thing1 tag", userid: thing2id, matchall: true).first
        assert Tag.strmatch("thing1 tag", userid: superid).first
        assert Tag.strmatch("thing1 tag").first
    end
    
    test "Admitting super-user for non-global tag makes it global" do
        thing1id = users(:thing1).id
        tagstr = "soon-to-be-global tag"
        assert_nil Tag.strmatch(tagstr, userid: thing1id).first, tagstr+" shouldn't match before asserting"
        # Asserting local tag, owned by thing1
        t = Tag.assert_tag(tagstr, userid: thing1id)
        # Check that it's indeed local
        assert_nil t.isGlobal, tagstr+" for specific user turned up global"
        # Check that thing1 can see it
        t = Tag.strmatch(tagstr, userid: thing1id).first
        assert t, "Can't find #{tagstr} on creator"
        
        superid = users(:super).id
        t = Tag.strmatch(tagstr, userid: superid).first
        assert t, "Can't find #{tagstr} on super"
        assert_nil t.isGlobal, "Super reading #{tagstr} turned it global"
        t.admit_user superid
        assert_equal t, Tag.strmatch(tagstr, userid: superid).first, "Admitting super as user changed tag"
        assert t.isGlobal, "Admitting super for local tag didn't make it global"
    end
    
    test "Admitting nil user for non-global tag makes it global" do
        thing1id = users(:thing1).id
        tagstr = "soon-to-be-global-by-nil tag"
        assert_nil Tag.strmatch(tagstr, userid: thing1id).first, tagstr+" shouldn't match before asserting"
        # Asserting local tag, owned by thing1
        t = Tag.assert_tag(tagstr, userid: thing1id)
        # Check that it's indeed local
        assert_nil t.isGlobal, tagstr+" for specific user turned up global"
        # Check that thing1 can see it
        t = Tag.strmatch(tagstr, userid: thing1id).first
        assert t, "Can't find #{tagstr} on creator"
        
        superid = users(:super).id
        t = Tag.strmatch(tagstr, userid: superid).first
        assert t, "Can't find #{tagstr} on super"
        assert_nil t.isGlobal, "Super reading #{tagstr} turned it global"
        t.admit_user
        assert_equal t, Tag.strmatch(tagstr, userid: superid).first, "Admitting nil as user changed tag"
        assert t.isGlobal, "Admitting nil for local tag didn't make it global"
    end
end