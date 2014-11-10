require 'test_helper'
class TemplateDecoratorTest < Draper::TestCase
  fixtures :users

  test "it creates a new templateer" do
    tt = TemplateDecorator.new User
    refute_nil tt
  end

  test "it generates the correct object type" do
    tt = TemplateDecorator.new User
    assert_equal "user", tt.object_type
    assert_equal "users", tt.object_type(true)
  end

  test "it generates correct human names" do
    tt = TemplateDecorator.new User
    assert_equal "user", tt.human_name
    assert_equal "users", tt.human_name.pluralize
    assert_equal "users", tt.human_name(true)
    assert_equal "user_id", tt.element_id(:id)
    assert_equal "user[id]", tt.field_name(:id)
    assert_equal "edit_user", tt.edit_class

    tt = TemplateDecorator.new FeedEntry
    assert_equal "feed entry", tt.human_name
    assert_equal "feed entries", tt.human_name.pluralize
    assert_equal "feed entries", tt.human_name(true)
    assert_equal "feed_entry_id", tt.element_id(:id)
    assert_equal "feed_entry[id]", tt.field_name(:id)
    assert_equal "edit_feed_entry", tt.edit_class

  end

  test "it gets attribute placeholder from nil object" do
    tt = TemplateDecorator.new User
    assert_equal "%%id%%", tt.id
  end

  test "it generates empty data map for nil object" do
    tt = TemplateDecorator.new User
    data = tt.data
    assert data.empty?
  end
end