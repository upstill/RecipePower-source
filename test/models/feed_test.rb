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
    test_feed.bkg_launch
    dj = test_feed.dj
    assert_equal ua, test_feed.updated_at
    assert test_feed.pending?
    test_feed.bkg_launch
    assert_equal dj, test_feed.dj # Calling enqueue a second time shouldn't affect the job

    test_feed.bkg_land
    assert test_feed.pending? # Got requeued
    assert_not_equal ua, test_feed.updated_at
    assert_not_equal dj, test_feed.dj
  end

  test 'launch_update behaves properly' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    test_feed.launch_update true
    assert test_feed.pending?
    ua = test_feed.updated_at
    test_feed.bkg_land
    assert_not_equal ua, test_feed.updated_at # Should have been updated

    # Launch_update should have no effect b/c the update is in the future
    test_feed.launch_update
    ua = test_feed.updated_at
    test_feed.bkg_land
    assert_equal ua, test_feed.updated_at # Should not have been updated

    # Launch_update should bring the update time back to the present
    test_feed.launch_update true
    assert (test_feed.dj.run_at <= Time.now)
    ua = test_feed.updated_at
    test_feed.bkg_land
    assert_not_equal ua, test_feed.updated_at # Should have been updated
  end

  test 'feed job gets deleted when feed does' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    ua = test_feed.updated_at
    sleep 1
    test_feed.bkg_launch
    assert_equal ua, test_feed.updated_at
    assert test_feed.pending?
    assert_equal test_feed.dj, Delayed::Job.last
    dj_id = test_feed.dj.id
    test_feed.bkg_land
    # test_feed.reload
    assert_equal test_feed.dj, Delayed::Job.last
    # When the job is executed, the feed should come back queued to a different job
    assert_not_equal dj_id, test_feed.dj.id, "feed update job not requeued"

    oj = test_feed.dj
    assert (oj.run_at > Time.now)
    # We're not forcing the sync so it doesn't actually execute
    test_feed.bkg_land
    # test_feed.reload
    assert_equal test_feed.dj, oj

    # Force the sync to execute
    test_feed.bkg_land!
    # We should have removed the prior job and launched a new one for the next update
    assert_not_equal test_feed.dj, oj

    ct = Delayed::Job.count
    test_feed.destroy
    assert (ct-1), Delayed::Job.count
  end

  test 'setting home with garbage fails' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    assert_not_nil test_feed.id
    test_feed.home = 'garbage'
    refute test_feed.save
    assert_not_empty test_feed.errors[:home]
  end

  test 'setting home to empty string succeeds' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    assert_not_nil test_feed.id
    test_feed.home = ''
    assert test_feed.save
    assert_empty test_feed.errors[:home]
  end

  test 'setting home with valid but failing URL fails' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    assert_not_nil test_feed.id
    test_feed.home = 'http://www.potatochipsarenotdinner'
    refute test_feed.save
    assert_not_empty test_feed.errors[:home]
  end

  test 'setting home with valid, successful URL succeeds' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes"
    assert_not_nil test_feed.id
    test_feed.home = 'http://www.potatochipsarenotdinner.com'
    assert test_feed.save
    refute test_feed.errors.any?
    assert test_feed.site.id
    refute test_feed.site.errors.any?
    assert test_feed.site.page_ref.id
    refute test_feed.site.page_ref.errors.any?
  end

  test 'creating with garbage in home fails' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes", home: 'garbage'
    assert_nil test_feed.id
    assert_not_empty test_feed.errors[:home]
  end

  test 'creating with empty string in home succeeds' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes", home: ''
    assert_not_nil test_feed.id
    refute test_feed.errors.any?
  end

  test 'creating with valid but failing URL in home fails' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes", home: 'http://www.potatochipsarenotdinner'
    assert_nil test_feed.id
    assert_not_empty test_feed.errors[:home]
  end

  test 'creating with valid, successful URL in home succeeds' do
    test_feed = Feed.create url: "http://feeds.feedburner.com/elise/simplyrecipes", home: 'http://www.potatochipsarenotdinner.com'
    assert_not_nil test_feed.id
    refute test_feed.errors.any?
    assert test_feed.site.id
    refute test_feed.site.errors.any?
    assert test_feed.site.page_ref.id
    refute test_feed.site.page_ref.errors.any?
  end

end