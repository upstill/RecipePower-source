class UserBrowserTest
end

require 'test_helper'
class UserBrowserTest < ActiveSupport::TestCase
  fixtures :feeds
  fixtures :users

  test "user has feeds" do
    user = users(:thing1)
    feed1 = feeds(:feed1)
    user.add_feed feed1
    feed2 = feeds(:feed2)
    user.add_feed feed2
    feed3 = feeds(:feed3)
    user.add_feed feed3
  end

  test "user can delete one feed" do
    user = users(:thing1)
    feed1 = feeds(:feed1)
    user.add_feed feed1
    feed2 = feeds(:feed2)
    user.add_feed feed2
    feed3 = feeds(:feed3)
    user.add_feed feed3
    user.delete_feed feed2
  end

  test "user can delete all feeds" do
    user = users(:thing1)
    feed1 = feeds(:feed1)
    user.add_feed feed1
    feed2 = feeds(:feed2)
    user.add_feed feed2
    feed3 = feeds(:feed3)
    user.add_feed feed3
    user.delete_feed feed1
    user.delete_feed feed2
    user.delete_feed feed3
  end
end

