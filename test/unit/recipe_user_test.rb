# encoding: UTF-8
require 'test_helper'
class RecipeUserTest < ActiveSupport::TestCase 
    fixtures :users
    fixtures :recipes
    
    def setup
      @rcp = recipes(:rcp)
      @thing1 = users(:thing1)
      @thing2 = users(:thing2)
    end
    
    test "doing first cookmark" do
      assert_equal 0, @rcp.num_cookmarks, "Should wake up with no cookmarks"
      assert !(@rcp.collectible_collected? @thing1.id), "Should wake up with no cookmark for user"
      @thing1.touch @rcp, true
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"

      @thing2.touch @rcp
      assert_equal 1, @rcp.num_cookmarks, "Cookmark count shouldn't change when touching without collecting"
      assert !@rcp.collectible_collected?(@thing2.id), "User shouldn't get cookmarked when touched without collecting"

      td1 = @rcp.touch_date @thing1.id
      sleep 6 # We can only touch things once in five seconds
      @thing1.touch @rcp
      assert_operator td1, :<, @rcp.touch_date(@thing1.id), "Touching should advance touch date"

      @thing2.touch @rcp, true
      assert_equal 2, @rcp.num_cookmarks, "Recipe's cookmark count should advance when cookmarked for second user"
      @rcp.uid = @thing2.id
      assert @rcp.collectible_collected?, "Recipe should get cookmarked for current user"
    end
    
    test "getting fields with no current user" do
      assert_equal "", @rcp.comment(@thing1.id)
    end
end
