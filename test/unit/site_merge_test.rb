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
    site1.home = site1.sample
    site1.name = "Vanilla Umami"
    site1.save
    site1.reload
    assert site1.page_ref
    assert site1.referent

    site2 = SiteServices.find_or_build_for "https://dinersjournal.blogs.nytimes.com/author/melissa-clark/" # sites(:nyt)
    site2.home = site2.sample
    site2.name = "NYT Blog"
    site2.description = "Some words about Site2"
    site2.logo = "data:kwljerkjk"
    site2.save
    site2.reload
    assert site2.page_ref
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
    assert_equal 2, site1.collectors.size
    assert_equal 2, site2.collectors.size
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
    # After absorbing, but before destroying, site2, its collections and votings should be unchanged
    assert site1.page_ref
    assert_equal 3, site1.collectors.size, "site2's users didn't transfer"
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
    assert_equal 2, tag2.taggings.size
    assert_equal 1, tag3.taggings.size
    assert_equal "Some words about Site2", site1.description, "Merge didn't copy description"
    assert_equal site2.logo, site1.logo, "Merge didn't copy image"

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
