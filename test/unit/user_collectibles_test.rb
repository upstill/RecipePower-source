require 'test_helper'
class UserCollectiblesTest < ActiveSupport::TestCase
  fixtures :users
  fixtures :recipes
  fixtures :feeds
  # fixtures :feed_entries
  # fixtures :lists
  # fixtures :products
  fixtures :sites
  test "Collectibles access methods defined" do
    user = users(:thing1)
    # feed_entry = feed_entries(:fe1)
    # list = lists(:list1)
    # product = products(:prod1)

    rcp = recipes(:rcp)
    assert user.recipes.empty?
    user.recipes<<rcp
    assert_equal 1, user.recipes.size
    refute user.recipes.empty?
    user.recipes.delete(rcp)
    assert user.recipes.empty?

    site = sites(:nyt)
    assert user.sites.empty?
    user.sites<<site
    assert_equal 1, user.sites.size
    refute user.sites.empty?
    user.sites.delete(site)
    assert user.sites.empty?

    feed = feeds(:feed1)
    assert user.feeds.empty?
    user.feeds<<feed
    assert_equal 1, user.feeds.size
    refute user.feeds.empty?
    user.feeds.delete(feed)
    assert user.feeds.empty?

    collected_user = users(:thing2)
    assert user.users.empty?
    user.users<<collected_user
    assert_equal 1, user.users.size
    refute user.users.empty?
    user.users.delete(collected_user)
    assert user.users.empty?

  end
end