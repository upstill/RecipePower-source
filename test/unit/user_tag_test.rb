# encoding: UTF-8
require 'test_helper'
class RecipeTagTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :users
    
    test "user has empty tag set" do
      assert_nil users(:thing3).current_user, "Recipe should start out without current user"
      users(:thing3).current_user = users(:thing1).id
      assert_equal users(:thing3).current_user, users(:thing1).id, "Recipe should adopt current user as id"
      assert_equal [], users(:thing3).tags, "Recipe should start out with no tags for thing1"
      users(:thing3).tag_ids = [tags(:jal).id]
      assert_equal users(:thing3).tag_ids[0], tags(:jal).id, "Recipe should have tag for thing1"
      users(:thing3).current_user = users(:thing2).id
      assert_equal [], users(:thing3).tags, "Recipe should NOT show tag for thing2"
    end
    
    test "user takes and removes different tag ids for different users" do
      thing1id = users(:thing1).id
      thing2id = users(:thing2).id
      jalid = tags(:jal).id
      chilibeanid = tags(:chilibean).id
      
      users(:thing3).current_user = thing1id
      users(:thing3).tag_ids = [jalid]
      
      users(:thing3).current_user = thing2id
      users(:thing3).tag_ids = [chilibeanid]
      
      assert_equal users(:thing3).tag_ids(thing1id), [jalid], "Recipe should have tag for thing1"
      assert_equal users(:thing3).tag_ids(thing2id), [chilibeanid], "Recipe should have tag for thing2"
      assert_equal 2, Tagging.count, "There should now be exactly two taggings"
      
      users(:thing3).current_user = thing1id
      users(:thing3).tag_ids = []
      assert_equal users(:thing3).tag_ids(thing1id), [], "Recipe should have removed tag for thing1"
      assert_equal users(:thing3).tag_ids(thing2id), [chilibeanid], "Recipe should still have tag for thing2"
    end
        
    test "user takes and removes different tags for different users" do
      thing1id = users(:thing1).id
      thing2id = users(:thing2).id
      jal = tags(:jal)
      chilibean = tags(:chilibean)
      
      users(:thing3).current_user = thing1id
      users(:thing3).tags = [jal]
      
      users(:thing3).current_user = thing2id
      users(:thing3).tags = [chilibean]
      
      assert_equal users(:thing3).tags(thing1id), [jal], "Recipe should have tag for thing1"
      assert_equal users(:thing3).tags(thing2id), [chilibean], "Recipe should have tag for thing2"
      assert_equal 2, Tagging.count, "There should now be exactly two taggings"
      
      users(:thing3).current_user = thing1id
      users(:thing3).tags = []
      assert_equal users(:thing3).tags(thing1id), [], "Recipe should have removed tag for thing1"
      assert_equal users(:thing3).tags(thing2id), [chilibean], "Recipe should still have tag for thing2"
      assert_equal 1, Tagging.count, "There should now be exactly one tagging"
    end
    
end
