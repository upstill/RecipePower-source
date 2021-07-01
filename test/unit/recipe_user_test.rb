# encoding: UTF-8
require 'test_helper'
class RecipeUserTest < ActiveSupport::TestCase 
    fixtures :users
    fixtures :recipes

    def setup
      super
      @rcp = recipes(:rcp)
      @rcp2 = recipes(:goodpicrcp)
      @thing1 = users(:thing1)
      @thing2 = users(:thing2)
    end

    test 'caches and saves rcprefs appropriately' do
      assert_equal '', @rcp.comment
      User.current = @thing1
      @rcp.comment= 'I told you so'
      assert_equal 'I told you so', @rcp.comment
      # Because this is a new rcpref, it gets saved
      @rcp.save
      @rcp.reload
      assert_equal 'I told you so', @rcp.comment

      # This time saving and reloading
      @rcp.comment= 'You told me so'
      assert_equal 'You told me so', @rcp.comment
      @rcp.save
      @rcp.reload
      assert_equal 'You told me so', @rcp.comment
      assert_equal 1, @rcp.toucher_pointers.count
      assert_equal 0, @rcp.collector_pointers.count
      assert_equal 1, @rcp.touchers.count
      assert_equal @thing1, @rcp.touchers.first
      assert_equal 0, @rcp.collector_pointers.count

      @thing1.save
      @thing1.reload
      assert_equal 'You told me so', @thing1.touched_pointers.first.comment
      assert_equal 1, @thing1.touched_pointers.count
      assert_equal 0, @thing1.collection_pointers.count
      assert_equal @rcp, @thing1.touched_pointers.first.entity
      refute @thing1.recipes.first  # No collected recipes
      assert_equal @rcp, @thing1.touched_recipes.first # ...but one touched recipe
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
      @rcp.reload
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
      @thing2.save # Should save the toucher_pointers in the user's cache, one of which points at @rcp
      @rcp.reload
      assert_equal 2, @rcp.num_cookmarks, "Recipe's cookmark count should advance when cookmarked for second user"
      User.current = @thing2
      @rcp.reload
      assert @rcp.collectible_collected?, "Recipe should get cookmarked for current user"
    end
    
    test "getting fields with no current user" do
      assert_equal "", @rcp.comment(@thing1.id)
    end
end
