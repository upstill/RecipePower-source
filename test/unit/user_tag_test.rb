# encoding: UTF-8
require 'test_helper'
class UserTagTest < ActiveSupport::TestCase 
    fixtures :tags
    fixtures :users

    def setup
      @thing1 = users(:thing1)
      @thing2 = users(:thing2)
      @tagee = users(:thing3)
      @jal = tags(:jal)
      @chilibean = tags(:chilibean)
    end

    test "user has empty tag set" do
      User.current = @thing1
      assert_equal [], @tagee.visible_tags, "@tagee should start out with no tags by @thing1"
      @tagee.tag_with @jal
      assert_equal @tagee.visible_tags.pluck(:id)[0], @jal.id, "@tagee should have tag for @jal due to @thing1"
    end

    test "user takes and removes different tag ids for different users" do
      tagging_count = Tagging.count
      thing1id = @thing1.id
      thing2id = @thing2.id
      jalid = @jal.id
      chilibeanid = @chilibean.id
      
      # Tag
      @tagee.tag_with @jal, thing1id
      @tagee.tag_with @chilibean, thing2id
      
      assert_equal 2, Tagging.count - tagging_count, "There should now be exactly two taggings"

      User.current = @thing1
      assert_equal [jalid], @tagee.visible_tags.pluck(:id), "@tagee should be tagged for :jal"

      User.current = @thing2
      assert_equal [chilibeanid], @tagee.visible_tags.pluck(:id), "@tagee should have tag for :chilibean"

      User.current = @thing1
      @tagee.shed_tag @jal
      assert_equal [], @tagee.visible_tags, "@tagee should no longer have tag by @thing1"

      User.current = @thing2
      assert_equal [chilibeanid], @tagee.visible_tags.pluck(:id), "@tagee should still have tag for @thing2"
    end
        
    test "user takes and removes different tags for different users" do
      tagging_count = Tagging.count
      thing1id = @thing1.id
      thing2id = @thing2.id

      User.current = @thing1
      @tagee.tag_with @jal

      User.current = @thing2
      @tagee.tag_with @chilibean

      User.current = @thing1
      assert_equal @tagee.visible_tags, [@jal], "@tagee should have tag for :chilibean"
      User.current = @thing2
      assert_equal @tagee.visible_tags, [@chilibean], "@tagee should have tag for :chilibean"
      assert_equal 2, Tagging.count-tagging_count, "There should now be exactly two taggings"
    end
    
end
