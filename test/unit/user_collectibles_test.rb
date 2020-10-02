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
    user.uncollect rcp
    # rcp.save
    user.save
    user.reload
    assert user.recipes.empty?

    rcp.reload
    assert_equal 0, rcp.collector_pointers.count
    assert_equal 1, rcp.toucher_pointers.count

    site = Site.find_or_build_for "https://dinersjournal.blogs.nytimes.com/author/melissa-clark/" # sites(:nyt)
    assert user.sites.empty?
    user.sites<<site
    assert_equal 1, user.sites.size
    refute user.sites.empty?
    user.uncollect site
    user.save
    user.reload
    assert user.sites.empty?

    feed = feeds(:feed1)
    assert user.feeds.empty?
    user.feeds<<feed
    assert_equal 1, user.feeds.size
    refute user.feeds.empty?
    user.uncollect feed
    user.save
    user.reload
    assert user.feeds.empty?

    collected_user = users(:thing2)
    assert user.followees.empty?
    user.followees<<collected_user
    assert_equal 1, user.followees.size
    refute user.followees.empty?
    user.uncollect collected_user
    user.save
    user.reload
    assert user.followees.empty?

  end

  test "User-side collection" do
    user = users(:thing1)
    rcp = recipes(:rcp)
    assert user.recipes.empty?
    user.touch rcp
    # Touching the recipe shouldn't mean it's in the collection
    assert user.collection_pointers.empty?
    assert user.recipes.empty?
    refute user.touched_pointers.empty?
    refute user.touched_pointers.first.in_collection
    assert rcp.collectors.empty?

    user.collect rcp
    user.save
    user.reload
    # ...though it will be among the collection_pointers and the recipes
    assert_equal 1, user.collection_pointers.size
    assert_equal 1, user.touched_pointers.size
    assert_equal rcp, user.recipes.first
    assert_equal 1, rcp.collectors.size
    assert_equal 1, user.recipes.size

    user.collect rcp  # Can only collect it once
    user.reload
    assert_equal 1, user.collection_pointers.size
    assert_equal 1, user.touched_pointers.size
    assert_equal rcp, user.recipes.first
    assert_equal 1, user.recipes.size
    assert_equal 1, rcp.collectors.size

    # Uncollecting it still leaves it touched
    user.uncollect rcp
    user.save ; user.reload
    assert user.collection_pointers.empty?
    assert user.recipes.empty?
    assert_equal 1, user.touched_pointers.size
    assert_equal 1, user.touched_recipes.size
    assert rcp.collectors.empty?
  end
end