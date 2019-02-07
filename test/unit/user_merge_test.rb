# encoding: UTF-8
require 'test_helper'
class UserMergeTest < ActiveSupport::TestCase
  fixtures :users

  test 'Correctly definining followers and followees' do
    user1 = users(:thing1)
    user2 = users(:thing2)
    user2.collect user1
    assert_equal 0, user1.followees.count
    assert_equal 1, user2.followees.count
    user1.save ; user1.reload
    user2.save ; user2.reload
    assert_equal 0, user1.followees.count
    assert_equal 1, user2.followees.count
    assert_equal 1, user1.touchers.count
    assert_equal 0, user2.touchers.count
  end

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
    user1.reload

    user2.collect dish2
    user2.collect dish3
    user2.collect user1
    user2.save
    user2.reload
    user1.reload

    fr1 = create(:user, username: "Follower1")
    fr2 = create(:user, username: "Follower2")
    fr3 = create(:user, username: "Follower3")
    user1.collectors << fr1
    user1.collectors << fr2
    user2.collectors << fr2
    user2.collectors << fr3

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
    user1.save ; user1.reload
    user2.save ; user2.reload

    assert_equal 2, user1.recipes.count, "# recipes of user1 not right"
    assert_equal 2, user2.recipes.count, "# recipes of user2 not right"
    assert_equal 2, user1.followees.count, "# followees of user1 not right"
    assert_equal 3, user2.followees.count, "# followees of user2 not right"
    assert_equal 3, user1.collectors.count, "# followers of user1 not right"
    assert_equal 2, user2.collectors.count, "# followers of user2 not right"

    user1.absorb user2
    user1.save
    user1.reload
    assert_equal 1, user1.votings.size, "Vote for dish1 didn't transfer from user2 to user1"
    assert_equal 2, dish1.upvotes, "dish1 should have two votes now."
    assert_equal "Some words about User2", user1.about, "Merge didn't copy about"
    assert_equal user2.image, user1.image, "Merge didn't copy image"
    assert_equal 3, user1.recipes.count, "After merge, # recipes of user1 not right"
    assert_equal 4, user1.collectors.count, "After merge, # followers of user1 not right"
    assert_equal 3, user1.followees.count, "After merge, # followees of user1 not right"
    user2.destroy
    assert_equal 1, dish1.upvotes, "dish1 should have one vote after destroying user."
    dish1.destroy
    assert_equal 2, user1.recipes.count, "After merge, # recipes of user1 not right"
    assert_equal 0, user1.votings.size, "user1 didn't lose a voting when dish1 was destroyed."

  end

end