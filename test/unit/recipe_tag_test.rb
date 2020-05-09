# encoding: UTF-8
require 'test_helper'
class RecipeTagTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :users
    fixtures :recipes

    def setup
      @rcp = recipes(:rcp)
      @user1 = users(:thing1)
      @user2 = users(:thing2)
      @jal = tags(:jal)
      @chilibean = tags(:chilibean)
    end
    
    test "recipe takes and removes different tag ids for different users" do
      tagging_count = Tagging.count

      @rcp.tag_with @jal, @user1.id
      @rcp.tag_with @chilibean, @user2.id
      User.current = @user1
      assert_equal [@jal.id], @rcp.visible_tags.pluck(:id), "Recipe should have tag for thing1"
      User.current = @user2
      assert_equal [@chilibean.id], @rcp.visible_tags.pluck(:id), "Recipe should have tag for thing2"
      assert_equal 2, Tagging.count-tagging_count, "There should now be exactly two taggings"
      
      User.current = @user1
      @rcp.refute_tagging @jal, @user1.id # TaggingServices.new(@rcp).refute @jal, @user1.id

      assert_equal @rcp.visible_tags.pluck(:id), [], "Recipe should have removed tag for thing1"
      User.current = @user2
      assert_equal @rcp.visible_tags.pluck(:id), [@chilibean.id], "Recipe should still have tag for thing2"

      # Should get the same result with explicitly assigned visibility
      User.current = @user1
      assert_equal [], @rcp.visible_tags.pluck(:id), "Recipe should have removed tag for thing1"
      User.current = @user2
      assert_equal [@chilibean.id], @rcp.visible_tags.pluck(:id), "Recipe should still have tag for thing2"
    end
        
    test "recipe takes and removes different tags for different users" do
      tagging_count = Tagging.count

      @rcp.tag_with @jal, @user1.id
      @rcp.tag_with @chilibean, @user2.id
      User.current = @user1
      assert_equal @rcp.visible_tags, [@jal], "Recipe should have tag for thing1"
      User.current = @user2
      assert_equal @rcp.visible_tags, [@chilibean], "Recipe should have tag for thing2"
      assert_equal 2, Tagging.count-tagging_count, "There should now be exactly two taggings"

      User.current = @user1
      @rcp.refute_tagging @jal # TaggingServices.new(@rcp).refute @jal
      assert_equal @rcp.visible_tags, [], "Recipe should have removed tag for thing1"
      User.current = @user2
      assert_equal @rcp.visible_tags, [@chilibean], "Recipe should still have tag for thing2"
      assert_equal 1, Tagging.count-tagging_count, "There should now be exactly one tagging"

      # Should get the same result with explicitly assigned visibility
      User.current = @user1
      assert_equal @rcp.visible_tags, [], "Recipe should have removed tag for thing1"
      User.current = @user2
      assert_equal @rcp.visible_tags, [@chilibean], "Recipe should still have tag for thing2"
    end
    
end
