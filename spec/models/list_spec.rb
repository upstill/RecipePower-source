require 'spec_helper'

describe List do
  fixtures :all
  pending "add some examples to (or delete) #{__FILE__}"

  it "should create a list with a name string" do
    tagee = FactoryGirl.create(:user)
    list_name = "Test List"
    list = List.assert list_name, tagee
    list.save
    assert_equal list_name, list.name, "new list name not stored"
    list2 = List.assert list_name, tagee
    assert_equal list, list2, "Re-using name tag created a different list"
  end
end
