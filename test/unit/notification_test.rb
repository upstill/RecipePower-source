# encoding: UTF-8
require 'test_helper'
class NotificationTest < ActiveSupport::TestCase 
  fixtures :users

  test "User Sends Notification" do
    source = users(:thing1)
    target = users(:thing2)
    source.send_notification(target, :share_recipe)
    notification = Notification.first
    assert_not_nil notification, "No notification exists after creation"
    assert_equal notification.source, source, "Notification doesn't have proper source"
    assert_equal notification.target, target, "Notification doesn't have proper target"
    assert_not_nil source.notifications_sent.first, "Source doesn't have notification sent"
    assert_not_nil target.notifications_received.first, "Target doesn't have notification received"
    assert_equal source.notifications_sent.first, notification, "Source doesn't have notification sent"
    assert_equal target.notifications_received.first, notification, "Target doesn't have notification received"
  end

  test "Deleting Sender Deletes Notification" do
    source = users(:thing1)
    target = users(:thing2)
    source.send_notification(target, :share_recipe)
    source.destroy
    assert_equal 0, Notification.count, "Still a notification after deleting Sender"
  end

  test "Deleting Receiver Deletes Notification" do
    source = users(:thing1)
    target = users(:thing2)
    source.send_notification(target, :share_recipe)
    target.destroy
    assert_equal 0, Notification.count, "Still a notification after deleting Target"
  end
=begin
  test "User Receives Notification" do
    rcp = Recipe.find_or_initialize( url: "http://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    assert rcp.errors.empty?, "Recipe should be initialized successfully"
  end

  test "User Creates Notification" do
    rcp = Recipe.find_or_initialize( url: "http://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    assert rcp.errors.empty?, "Recipe should be initialized successfully"
  end
=end
end