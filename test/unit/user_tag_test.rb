# encoding: UTF-8
require 'test_helper'
class UserTagTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :users
    
    test "user has empty tag set" do
      thing1 = users(:thing1)
      thing2 = users(:thing2)
      tagee = users(:thing3)
      jal = tags(:jal)
      assert_nil tagee.current_user, "tagee should start out without current user"
      tagee.current_user = thing1.id
      assert_equal tagee.current_user, thing1.id, "tagee should adopt thing1 as current user"
      assert_equal [], tagee.tags, "tagee should start out with no tags by thing1"
      tagee.tag_ids = [jal.id]
      assert_equal tagee.tag_ids[0], jal.id, "tagee should have tag for jal due to thing1"
      tagee.current_user = thing2.id
      assert_equal tagee.current_user, thing2.id, "tagee should adopt thing2 as current user"
      assert_equal [jal.id], tagee.tag_ids, "User tagee should see tag asserted by thing2"
    end
    
    test "user takes and removes different tag ids for different users" do
      thing1id = users(:thing1).id
      thing2id = users(:thing2).id
      tagee = users(:thing3)
      jalid = tags(:jal).id
      chilibeanid = tags(:chilibean).id
      
      # Tag 
      tagee.current_user = thing1id
      tagee.tag_ids = tagee.tag_ids + [jalid]
      
      tagee.current_user = thing2id
      tagee.tag_ids = tagee.tag_ids + [chilibeanid]
      
      assert_equal 2, Tagging.count, "There should now be exactly two taggings"
      assert tagee.tag_ids(thing1id).include?(jalid), "tagee should be tagged for :jal"
      assert tagee.tag_ids(thing2id).include?(chilibeanid), "tagee should have tag for :chilibean"
      
      tagee.current_user = thing1id
      tagee.tag_ids = tagee.tag_ids - [jalid]
      assert_equal tagee.tag_ids(thing1id), [chilibeanid], "tagee should still have tag for thing1"
      assert_equal tagee.tag_ids(thing2id), [chilibeanid], "tagee should still have tag for thing2"
    end
        
    test "user takes and removes different tags for different users" do
      thing1id = users(:thing1).id
      thing2id = users(:thing2).id
      tagee = users(:thing3)
      jal = tags(:jal)
      chilibean = tags(:chilibean)
      
      tagee.current_user = thing1id
      tagee.tags = [jal]
      
      tagee.current_user = thing2id
      tagee.tags = [chilibean]
      
      assert_equal tagee.tags(thing1id), [chilibean], "tagee should have tag for :chilibean"
      assert_equal tagee.tags(thing2id), [chilibean], "tagee should have tag for :chilibean"
      assert_equal 1, Tagging.count, "There should now be exactly two taggings"
      
      tagee.current_user = thing1id
      tagee.tags = []
      assert_equal [], tagee.tags(thing1id), "tagee should have removed tag for thing1"
      assert_equal [], tagee.tags(thing2id), "tagee should have removed tag for thing2"
      assert_equal 0, Tagging.count, "There should now be exactly one tagging"
    end
    
end
