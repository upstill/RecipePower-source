# encoding: UTF-8
require 'test_helper'
class SiteMergeTest < ActiveSupport::TestCase
  fixtures :sites
  fixtures :users
  fixtures :tags

  # TODO Need to test for merge:
  # -- user's tags get successfully passed
  test "Successfully creating sites" do
    Tagging.all.each { |tagging| tagging.destroy }
    site1 = sites(:umami1)
    site1.include_url site1.sample
    site1.name = "Vanilla Umami"
    site1.save
    assert_equal 1, site1.references.size
    assert site1.referent

    site2 = sites(:umami2)
    site2.include_url site2.sample
    site2.name = "Umami Blog"
    site2.description = "Some words about Site2"
    site2.logo = "data:kwljerkjk"
    site2.save
    assert_equal 1, site2.references.size
    assert site2.referent

    user1 = users :thing1
    user2 = users :thing2
    user3 = users :thing3
    user1.collect site1
    user2.collect site1
    user2.collect site2
    user3.collect site2

    user1.vote site1
    user2.vote site1
    user2.vote site2
    user3.vote site2

    tag1 = tags :jal
    tag2 = tags :jal2
    tag3 = tags :dessert
    site1.tag_with tag1, user1.id
    site1.tag_with tag2, user1.id
    site2.tag_with tag2, user2.id
    site2.tag_with tag3, user2.id

    site2.reload
    assert_equal 2, site1.users.size
    assert_equal 2, site2.users.size
    assert_equal 1, user1.sites.size
    assert_equal 2, user2.sites.size
    assert_equal 1, user3.sites.size
    assert_equal 2, site1.votes.size
    assert_equal 2, site2.votes.size
    assert_equal 1, user1.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 2, user2.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 1, user3.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 2, site1.tags.size
    assert_equal 2, site2.tags.size
    assert_equal 1, site1.taggers.size
    assert_equal 1, site2.taggers.size
    assert_equal 1, tag1.taggings.size
    assert_equal 2, tag2.taggings.size
    assert_equal 1, tag3.taggings.size

    site1.absorb site2
    site1.save
    site1.reload
    site2.reload
    # After absorbing, but before destroying, site2, its collections and votings should be unchanged
    assert_equal 2, site1.references.size
    assert_equal 3, site1.users.size, "site2's users didn't transfer"
    assert_equal 3, site1.votes.size, "Vote didn't transfer from site2 to site1"
    assert_equal 1, user1.sites.size
    assert_equal 2, user2.sites.size
    assert_equal 2, user3.sites.size
    assert_equal 3, site1.votes.size
    assert_equal 1, user1.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 2, user2.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 2, user3.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 3, site1.tags.size
    assert_equal 2, site2.tags.size
    assert_equal 2, site1.taggers.size
    assert_equal 1, site2.taggers.size
    assert_equal 1, tag1.taggings.size
    assert_equal 3, tag2.taggings.size
    assert_equal 2, tag3.taggings.size
    assert_equal "Some words about Site2", site1.description, "Merge didn't copy description"
    assert_equal site2.logo, site1.logo, "Merge didn't copy image"
    site2.destroy

    # Having absorbed the other site, destroying it should have no impact on site1's resources
    assert_equal 2, site1.references.size
    assert_equal 3, site1.users.size, "site2's users didn't transfer"
    assert_equal 3, site1.votes.size, "Vote didn't transfer from site2 to site1"
    assert_equal 1, user1.sites.size
    assert_equal 1, user2.sites.size
    assert_equal 1, user3.sites.size
    assert_equal 3, site1.votes.size
    assert_equal 1, user1.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 1, user2.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 1, user3.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 3, site1.tags.size
    assert_equal 2, site1.taggers.size
    assert_equal 1, tag1.taggings.size
    assert_equal 2, tag2.taggings.size # One each from user1 and user2
    assert_equal 1, tag3.taggings.size

    site1.destroy
    assert_equal 0, user1.sites.size
    assert_equal 0, user2.sites.size
    assert_equal 0, user3.sites.size
    assert_equal 0, user1.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 0, user2.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 0, user3.votings.size, "user1 didn't lose a voting when dish1 was destroyed."
    assert_equal 0, tag1.taggings.size
    assert_equal 0, tag2.taggings.size
    assert_equal 0, tag3.taggings.size

  end

end