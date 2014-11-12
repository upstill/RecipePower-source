require 'test_helper'

class UserDecoratorTest < Draper::TestCase
  fixtures :users

  test "it creates a new templating decorator" do
    user = users(:thing1)
    tt = UserDecorator.new user
    assert_equal user, tt.object
  end

  test "it generates the correct object type" do
    user = users(:thing1)
    tt = UserDecorator.new user
    assert_equal "user", tt.object_type
    assert_equal "users", tt.object_type(true)

  end

  test "it generates correct human names" do
    user = users(:thing1)
    tt = UserDecorator.new user
    assert_equal "user", tt.human_name(false, false) # Not plural, not capitalized
    assert_equal "users", tt.human_name(true, false)
    assert_equal "user_id", tt.element_id(:id)
    assert_equal "user[id]", tt.field_name(:id)
    assert_equal "/users/#{user.id}", tt.object_path
    assert_equal "/users/#{user.id}/edit", tt.edit_path
    assert_equal "edit_user", tt.edit_class

  end

  test "it gets attribute placeholder from object" do
    user = users(:thing1)
    tt = UserDecorator.new user
    assert_equal user.id, tt.id
  end

  test "it generates data map for object" do
    user = users(:thing1)
    tt = UserDecorator.new user
    assert_equal user.id, tt.id
    assert_equal user.remember_me, tt.remember_me
    data = tt.data
    assert_equal user.id, data[:id]
    assert_equal user.remember_me, data[:remember_me]
  end
end