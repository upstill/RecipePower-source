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
    @owner.add_followee @friend

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

