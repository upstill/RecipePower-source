require 'test_helper'
require 'templateer.rb'
class TypeMapTest < ActiveSupport::TestCase
  fixtures :users

  test "it creates a new templateer" do
    tt = Templateer.new User
    refute_nil tt
    user = users(:thing1)
    tt = Templateer.new user
    assert_equal user, tt.object
  end

  test "it generates the correct object type" do
    tt = Templateer.new User
    assert_equal "user", tt.object_type
    assert_equal "users", tt.object_type(true)

    user = users(:thing1)
    tt = Templateer.new user
    assert_equal "user", tt.object_type
    assert_equal "users", tt.object_type(true)

  end

  test "it generates correct human names" do
    tt = Templateer.new User
    assert_equal "user", tt.human_name
    assert_equal "users", tt.human_name.pluralize
    assert_equal "users", tt.human_name(true)
    assert_equal "user_id", tt.element_id(:id)
    assert_equal "user[id]", tt.field_name(:id)
    assert_equal "/users/%%id%%", tt.object_path
    assert_equal "/users/%%id%%/edit", tt.edit_path
    assert_equal "edit_user", tt.edit_class

    user = users(:thing1)
    tt = Templateer.new user
    assert_equal "user", tt.human_name
    assert_equal "users", tt.human_name.pluralize
    assert_equal "users", tt.human_name(true)
    assert_equal "user_id", tt.element_id(:id)
    assert_equal "user[id]", tt.field_name(:id)
    assert_equal "/users/#{user.id}", tt.object_path
    assert_equal "/users/#{user.id}/edit", tt.edit_path
    assert_equal "edit_user", tt.edit_class

    tt = Templateer.new FeedEntry
    assert_equal "feed entry", tt.human_name
    assert_equal "feed entries", tt.human_name.pluralize
    assert_equal "feed entries", tt.human_name(true)
    assert_equal "feed_entry_id", tt.element_id(:id)
    assert_equal "feed_entry[id]", tt.field_name(:id)
    assert_equal "/feed_entries/%%id%%", tt.object_path
    assert_equal "edit_feed_entry", tt.edit_class

  end

  test "it gets attribute placeholder from nil object" do
    tt = Templateer.new User
    assert_equal "%%id%%", tt.id

    user = users(:thing1)
    tt = Templateer.new user
    assert_equal user.id, tt.id
  end

  test "it generates data map for object" do
    tt = Templateer.new User
    data = tt.data
    assert data.empty?

    user = users(:thing1)
    tt = Templateer.new user
    assert_equal user.id, tt.id
    assert_equal user.remember_me, tt.remember_me
    data = tt.data
    assert_equal user.id, data[:id]
    assert_equal user.remember_me, data[:remember_me]
  end
end