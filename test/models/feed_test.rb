require 'test_helper'

class FeedTest < ActiveSupport::TestCase

  test 'save does not affect timestamps' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    ua = test_feed.updated_at
    sleep 1
    test_feed.save
    assert !test_feed.errors.any?, test_feed.errors.first.to_s
    assert_equal ua, test_feed.updated_at
  end

  test 'hard_save does affect timestamps' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    ua = test_feed.updated_at
    sleep 1
    test_feed.hard_save
    assert !test_feed.errors.any?, test_feed.errors.first.to_s
    assert_not_equal ua, test_feed.updated_at
  end

  test 'feed queued and processed correctly' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    ua = test_feed.updated_at
    sleep 1
    test_feed.bkg_enqueue
    assert_equal ua, test_feed.updated_at
    assert test_feed.pending?
    test_feed.bkg_sync
    refute test_feed.pending?
    assert_not_equal ua, test_feed.updated_at

    test_feed.launch_update
    refute test_feed.pending?
    ua = test_feed.updated_at
    test_feed.bkg_sync
    assert_equal ua, test_feed.updated_at # Should have no update

    test_feed.launch_update true
    assert test_feed.pending?
  end

end