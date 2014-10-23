# encoding: UTF-8
require 'test_helper'
class RecipeUserTest < ActiveSupport::TestCase 
    fixtures :users
    fixtures :recipes
    
    test "doing first cookmark" do
      assert_equal 0, recipes(:rcp).num_cookmarks, "Should wake up with no cookmarks"
      assert !(recipes(:rcp).collected_by? users(:thing1).id), "Should wake up with no cookmark for user"
      recipes(:rcp).current_user = users(:thing1).id
      recipes(:rcp).touch
      assert_equal 1, recipes(:rcp).num_cookmarks, "User should get cookmarked"
      recipes(:rcp).current_user = users(:thing2).id
      
      recipes(:rcp).touch false
      assert_equal 1, recipes(:rcp).num_cookmarks, "Cookmark count shouldn't change when touching without collecting"
      assert !recipes(:rcp).collected_by?, "User shouldn't get cookmarked when touched without collecting"

      td1 = recipes(:rcp).touch_date
      cd1 = recipes(:rcp).collection_date
      recipes(:rcp).touch false
      assert (td1 < recipes(:rcp).touch_date), "Touching should advance touch date"
      assert_equal cd1, recipes(:rcp).collection_date, "Touching shouldn't advance collection date"
      
      recipes(:rcp).touch
      assert_equal 2, recipes(:rcp).num_cookmarks, "Recipe's cookmark count should advance when cookmarked for current user"
      assert recipes(:rcp).collected_by?, "Recipe should get cookmarked for current user"
    end
    
    test "getting fields with no current user" do
      assert_equal "", recipes(:rcp).comment(users(:thing1).id)
    end
    
    test "setting fields with no current user" do
    end
    
    test "accumulating reference before save" do 
    end
    
    test "cookmarking indicators before touching" do
    end
    
    test "cookmarking indicators after touching without collection" do
    end
    
    test "cookmarking indicators after collecting" do
    end
end
