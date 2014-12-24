# encoding: UTF-8
require 'test_helper'
class UserMergeTest < ActiveSupport::TestCase
  fixtures :users

  test "Successfully creating users" do
    user1 = users(:thing1)
    user2 = users(:thing2)
    user2.about = "Some words about User2"
    user2.image = "data:kwljerkjk"

    img = user2.image
    dish1 = create(:recipe)
    dish2 = create(:recipe)
    dish3 = create(:recipe)
    user1.recipes << dish1
    user1.recipes << dish2
    user1.save

    user2.touch dish2, true
    user2.touch dish3, true
    user2.save

    fr1 = create(:user, username: "Follower1")
    fr2 = create(:user, username: "Follower2")
    fr3 = create(:user, username: "Follower3")
    user1.followers << fr1
    user1.followers << fr2
    user2.followers << fr2
    user2.followers << fr3

    assert_equal 0, user1.votings.size, "Users should be born with no votes"
    assert_equal 0, user2.votings.size, "Users should be born with no votes"
    user2.vote dish1
    user2.reload
    assert_equal 0, user1.votings.size, "Wrong user got to vote"
    assert_equal 1, dish1.upvotes, "dish1 not voted on by user2"
    assert_equal 1, user2.votings.size, "user2 doesn't have voting for dish1"

    fe1 = create(:user, username: "Followee1")
    fe2 = create(:user, username: "Followee2")
    fe3 = create(:user, username: "Followee3")
    user1.followees << fe1
    user1.followees << fe2
    user2.followees << fe2
    user2.followees << fe3

    assert_equal 2, user1.collection_pointers.count, "# recipes of user1 not right"
    assert_equal 2, user2.collection_pointers.count, "# recipes of user2 not right"
    assert_equal 2, user1.followees.count, "# followees of user1 not right"
    assert_equal 2, user2.followees.count, "# followees of user2 not right"
    assert_equal 2, user1.followers.count, "# followers of user1 not right"
    assert_equal 2, user2.followers.count, "# followers of user2 not right"

    user1.absorb user2
    user1.save
    user1.reload
    assert_equal 1, user1.votings.size, "Vote didn't transfer from user2 to user1"
    assert_equal 2, dish1.upvotes, "dish1 should have two votes now."
    assert_equal "Some words about User2", user1.about, "Merge didn't copy about"
    assert_equal user2.image, user1.image, "Merge didn't copy image"
    assert_equal 3, user1.recipes.count, "After merge, # recipes of user1 not right"
    assert_equal 3, user1.followers.count, "After merge, # followers of user1 not right"
    assert_equal 3, user1.followees.count, "After merge, # followees of user1 not right"
  end

end