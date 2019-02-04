# encoding: UTF-8
require 'test_helper'
class RecipeUserTest < ActiveSupport::TestCase 
    fixtures :users
    fixtures :recipes
    
    def setup
      @rcp = recipes(:rcp)
      @rcp2 = recipes(:goodpicrcp)
      @thing1 = users(:thing1)
      @thing2 = users(:thing2)
    end

    test 'maintains rcprefs during touching' do
      assert_equal 0, @rcp.num_cookmarks, "Should wake up with no cookmarks"
      assert !(@rcp.collectible_collected? @thing1.id), "Should wake up with no cookmark for user"
      @thing1.touch @rcp
      assert_equal 0, @rcp.num_cookmarks, "Recipe should not get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 0, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 0, @thing1.collection_pointers.count
      assert_equal 0, @thing1.public_pointers.count
      @rcp.save
      assert_equal 0, @rcp.num_cookmarks, "Recipe should not get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 0, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 0, @thing1.collection_pointers.count
      assert_equal 0, @thing1.public_pointers.count
      @thing1.save
      assert_equal 0, @rcp.num_cookmarks, "Recipe should not get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 0, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 0, @thing1.collection_pointers.count
      assert_equal 0, @thing1.public_pointers.count
      @rcp.reload
      assert_equal 0, @rcp.num_cookmarks, "Recipe should not get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 0, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 0, @thing1.collection_pointers.count
      assert_equal 0, @thing1.public_pointers.count
      @thing1.reload
      assert_equal 0, @rcp.num_cookmarks, "Recipe should not get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 0, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 0, @thing1.collection_pointers.count
      assert_equal 0, @thing1.public_pointers.count

    end

    test 'maintains rcprefs during collecting' do
      assert_equal 0, @rcp.num_cookmarks, "Should wake up with no cookmarks"
      assert !(@rcp.collectible_collected? @thing1.id), "Should wake up with no cookmark for user"
      @thing1.collect @rcp
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 1, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 1, @thing1.collection_pointers.count
      assert_equal 1, @thing1.public_pointers.count
      @rcp.save
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 1, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 1, @thing1.collection_pointers.count
      assert_equal 1, @thing1.public_pointers.count
      @thing1.save
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 1, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 1, @thing1.collection_pointers.count
      assert_equal 1, @thing1.public_pointers.count
      @rcp.reload
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 1, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 1, @thing1.collection_pointers.count
      assert_equal 1, @thing1.public_pointers.count
      @thing1.reload
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 1, @rcp.collector_pointers.count
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 1, @thing1.collection_pointers.count
      assert_equal 1, @thing1.public_pointers.count
    end

    test 'touching advances touch_date' do
      @thing1.collect @rcp
      td1 = @rcp.touch_date @thing1.id
      sleep 6 # We can only touch things once in five seconds
      @thing1.touch @rcp
      @thing1.save
      assert_operator td1, :<, @rcp.touch_date(@thing1.id), "Touching should advance touch date"
    end

    test "doing first cookmark" do
      assert_equal 0, @rcp.num_cookmarks, "Should wake up with no cookmarks"
      assert !(@rcp.collectible_collected? @thing1.id), "Should wake up with no cookmark for user"
      @thing1.collect @rcp
      assert_equal 1, @rcp.num_cookmarks, "Recipe should get cookmarked when user touches it"

      @thing2.touch @rcp
      assert_equal 1, @rcp.num_cookmarks, "Cookmark count shouldn't change when touching without collecting"
      assert !@rcp.collectible_collected?(@thing2.id), "User shouldn't get cookmarked when touched without collecting"

      @thing2.collect @rcp
      assert_equal 2, @rcp.num_cookmarks, "Recipe's cookmark count should advance when cookmarked for second user"
      User.current = @thing2
      @rcp.reload
      assert @rcp.collectible_collected?, "Recipe should get cookmarked for current user"
    end
    
    test "getting fields with no current user" do
      assert_equal "", @rcp.comment(@thing1.id)
    end
end
