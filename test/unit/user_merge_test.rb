# encoding: UTF-8
require 'test_helper'
class UserMergeTest < ActiveSupport::TestCase

  test "Successfully creating users" do
    user1 = create(:user, username: "user1")
    user2 = create(:user, username: "user2")

    dish1 = create(:recipe)
    dish2 = create(:recipe)
    dish3 = create(:recipe)
    user1.recipes << dish1
    user1.recipes << dish2
    user1.save

    dish2.touch true, user2
    dish3.touch true, user2
    # user2.recipes << dish2
    # user2.recipes << dish3

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

    assert_equal 2, user1.recipes.count, "# recipes of user1 not right"
    assert_equal 2, user2.recipes.count, "# recipes of user2 not right"
    assert_equal 2, user1.followees.count, "# followees of user1 not right"
    assert_equal 2, user2.followees.count, "# followees of user2 not right"
    assert_equal 2, user1.followers.count, "# followers of user1 not right"
    assert_equal 2, user2.followers.count, "# followers of user2 not right"
  end

end