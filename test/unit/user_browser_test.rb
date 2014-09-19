class UserBrowserTest
end

require 'test_helper'
class UserBrowserTest < ActiveSupport::TestCase
  fixtures :feeds
  fixtures :users

  test "user has feeds" do
    user = users(:thing1)
    feed1 = feeds(:feed1)
    user.feeds << feed1
    feed2 = feeds(:feed2)
    user.feeds << feed2
    feed3 = feeds(:feed3)
    user.feeds << feed3
  end

  test "user can delete one feed" do
    user = users(:thing1)
    feed1 = feeds(:feed1)
    user.feeds << feed1
    feed2 = feeds(:feed2)
    user.feeds << feed2
    feed3 = feeds(:feed3)
    user.feeds << feed3
    user.feeds.delete feed2
    user.save
  end

  test "user can delete all feeds" do
    user = users(:thing1)
    feed1 = feeds(:feed1)
    user.feeds << feed1
    feed2 = feeds(:feed2)
    user.feeds << feed2
    feed3 = feeds(:feed3)
    user.feeds << feed3
    user.feeds.delete feed1
    user.feeds.delete feed2
    user.feeds.delete feed3
    user.save
  end
end

