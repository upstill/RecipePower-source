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
    assert_equal "user", tt.human_name(false, false)
    assert_equal "users", tt.human_name(true, false)
    assert_equal "Users", tt.human_name(true, true)
    assert_equal "user_id", tt.element_id(:id)
    assert_equal "user[id]", tt.field_name(:id)
    assert_equal "edit_user", tt.edit_class

    tt = TemplateDecorator.new FeedEntry
    assert_equal "feed entry", tt.human_name(false, false)
    assert_equal "feed entries", tt.human_name(true, false)
    assert_equal "feed_entry_id", tt.element_id(:id)
    assert_equal "feed_entry[id]", tt.field_name(:id)
    assert_equal "edit_feed_entry", tt.edit_class

  end

  test "it gets attribute placeholder from nil object" do
    tt = TemplateDecorator.new User
    assert_equal "%%id%%", tt.id
  end

  test "it generates proper placeholders for nil type" do
    tt = TemplateDecorator.new
    assert_equal "%%objTypeSingular%%", tt.data[:objTypeSingular]
    assert_equal "%%objTypePlural%%", tt.data[:objTypePlural]
    assert_equal "%%objTypeSingular%%_blah", tt.element_id(:blah)
    assert_equal "%%objTypeSingular%%[blah]", tt.field_name(:blah)
    assert_equal "/%%objTypePlural%%/%%id%%", tt.object_path
    assert_equal "/%%objTypePlural%%/%%id%%/edit", tt.edit_path
    assert_equal "edit_%%objTypeSingular%%", tt.edit_class
    assert_equal "%%humanName%%", tt.data[:humanName]
    assert_equal "%%humanNameCapitalize%%", tt.data[:humanNameCapitalize]
    assert_equal "%%humanNamePlural%%", tt.data[:humanNamePlural]
    assert_equal "%%humanNamePluralCapitalize%%", tt.data[:humanNamePluralCapitalize]
  end
end