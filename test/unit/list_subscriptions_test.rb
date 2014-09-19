require 'test/unit'
require 'test_helper'
class ListSubscriptionsTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @super = users(:super)
    @guest = users(:guest)
    @owner = users(:thing1)
    @other = users(:thing2)
    @friend = users(:thing3)
    @owner.followees << @friend unless @owner.followee_ids.include?(@friend.id)
    @owner.save

    @lst_name = "Test List"
    @lst = List.assert @lst_name, @owner
    @super_lst = List.assert "Super List", @super
    # Get a recipe under a tag
    @lst.include (@included = FactoryGirl.create(:recipe))
    @lstsvc = ListServices.new(@lst)
    @super_lstsvc = ListServices.new(@super_lst)
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test "a user must explicitly subscribe to a public list" do
    refute @owner.subscribes_to(@super_lst)
    @owner.subscribe_to @super_lst
    assert @owner.subscribes_to(@super_lst)
  end

  test "unsubscribing removes a list from subscriptions" do
    assert @owner.subscribes_to @lst
    @owner.subscribe_to @lst, false
    refute @owner.subscribes_to @lst
  end

  test "a user can only subscribe to a list once" do
    subcount = @owner.lists.count
    refute @owner.subscribes_to(@super_lst)
    @owner.subscribe_to @super_lst
    assert @owner.subscribes_to(@super_lst)
    assert_equal (subcount+1), @owner.lists.count
    @owner.subscribe_to @super_lst
    assert_equal (subcount+1), @owner.lists.count, "List got added to subscriptions twice"
  end

  test "a user is automatically subscribed to a new list" do
    assert @lstsvc.subscribed_by?(@owner)
    assert ListServices.subscribed_by(@owner).include?(@lst)
    refute @lstsvc.subscribed_by?(@other)
    refute ListServices.subscribed_by(@other).include?(@lst)
    @lstsvc.subscribe @other
    assert @lstsvc.subscribed_by?(@other)
    assert ListServices.subscribed_by(@other).include?(@lst)
  end

  test "a list defaults to visibility by others" do
    @lst.typenum = :public
    assert @lstsvc.available_to?(@owner)
    assert @lstsvc.available_to?(@super)
    assert @lstsvc.available_to?(@other)
    assert @lstsvc.available_to?(@friend)
    @lst.typenum = :friends
    assert @lstsvc.available_to?(@owner)
    assert @lstsvc.available_to?(@super)
    refute @lstsvc.available_to?(@other)
    assert @lstsvc.available_to?(@friend)
    @lst.typenum = :private
    assert @lstsvc.available_to?(@owner)
    assert @lstsvc.available_to?(@super)
    refute @lstsvc.available_to?(@other)
    refute @lstsvc.available_to?(@friend)
  end

end

