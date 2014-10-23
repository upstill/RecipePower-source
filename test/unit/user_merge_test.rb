# encoding: UTF-8
require 'test_helper'
class UserMergeTest < ActiveSupport::TestCase

  test "Successfully creating users" do
    # user1 = create(:user, username: "user1")
    channel1 = create(:channel_referent, tag_token: "user1s channel")
    user1 = channel1.user
    # user2 = create(:user, username: "user2", about: "Some words about User2", image: "data:kwljerkjk")
    channel2 = create(:channel_referent, tag_token: "user2s channel")
    user2 = channel2.user
    user2.about = "Some words about User2"
    user2.image = "data:kwljerkjk"

    img = user2.image
    dish1 = create(:recipe)
    dish2 = create(:recipe)
    dish3 = create(:recipe)
    user1.recipes << dish1
    user1.recipes << dish2
    user1.save

    dish2.touch true, user2
    dish3.touch true, user2

    fr1 = create(:user, username: "Follower1")
    fr2 = create(:user, username: "Follower2")
    fr3 = create(:user, username: "Follower3")
    user1.followers << fr1
    user1.followers << fr2
    user2.followers << fr2
    user2.followers << fr3

    fe1 = create(:user, username: "Followee1")
    fe2 = create(:user, username: "Followee2")
    fe3 = create(:user, username: "Followee3")
    user1.followees << fe1
    user1.followees << fe2
    user2.followees << fe2
    user2.followees << fe3

    assert_equal 2, user1.collection_size, "# recipes of user1 not right"
    assert_equal 2, user2.collection_size, "# recipes of user2 not right"
    assert_equal 2, user1.followees.count, "# followees of user1 not right"
    assert_equal 2, user2.followees.count, "# followees of user2 not right"
    assert_equal 2, user1.followers.count, "# followers of user1 not right"
    assert_equal 2, user2.followers.count, "# followers of user2 not right"

    user1.merge user2
    assert_equal "Some words about User2", user1.about, "Merge didn't copy about"
    assert_equal "data:kwljerkjk", user1.image, "Merge didn't copy image"
    user2.about = "About which shouldn't be copied"
    user2.image = "image which shouldn't be copied"
    user1.merge user2
    channel2.destroy
    begin
      user2.reload
      assert_equal 1, 2, "Deleting channel didn't delete user"
    rescue Exception => e
      assert_equal ActiveRecord::RecordNotFound, e.class, "Deleting channel didn't delete user"
    end
    user1.reload
    assert_equal 3, user1.collection_size, "After merge, # recipes of user1 not right"
    assert_equal 3, user1.followers.count, "After merge, # followers of user1 not right"
    assert_equal 3, user1.followees.count, "After merge, # followees of user1 not right"
    assert_equal "Some words about User2", user1.about, "Merge copied about inappropriately"
    assert_equal "data:kwljerkjk", user1.image, "Merge copied image inappropriately"
  end

end