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
    dj = test_feed.dj
    assert_equal ua, test_feed.updated_at
    assert test_feed.pending?
    test_feed.bkg_enqueue
    assert_equal dj, test_feed.dj # Calling enqueue a second time shouldn't affect the job

    test_feed.bkg_sync
    assert test_feed.pending? # Got requeued
    assert_not_equal ua, test_feed.updated_at
    assert_not_equal dj, test_feed.dj
  end

  test 'launch_update behaves properly' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    test_feed.launch_update true
    assert test_feed.pending?
    ua = test_feed.updated_at
    test_feed.bkg_sync
    assert_not_equal ua, test_feed.updated_at # Should have been updated

    # Launch_update should have no effect b/c the update is in the future
    test_feed.launch_update
    ua = test_feed.updated_at
    test_feed.bkg_sync
    assert_equal ua, test_feed.updated_at # Should have been updated
  end

  test 'feed job gets deleted when feed does' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    ua = test_feed.updated_at
    sleep 1
    test_feed.bkg_enqueue
    assert_equal ua, test_feed.updated_at
    assert test_feed.pending?
    assert 1, Delayed::Job.count
    test_feed.bkg_sync
    # test_feed.reload
    assert 1, Delayed::Job.count
    assert_equal test_feed.dj, Delayed::Job.first

    # When the job is executed, the feed should come back queued to a different job
    oj = test_feed.dj
    # We're not forcing the sync so it doesn't actually execute
    test_feed.bkg_sync
    # test_feed.reload
    assert_equal test_feed.dj, oj

    # Force the sync to execute
    test_feed.bkg_sync true
    # test_feed.reload
    assert_not_equal test_feed.dj, oj

    assert 1, Delayed::Job.count
    test_feed.destroy
    assert 0, Delayed::Job.count
  end

end