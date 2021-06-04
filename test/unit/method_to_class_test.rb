# require 'test/unit'
require 'test_helper'
require 'string_utils.rb'
class MethodToClassTest < ActiveSupport::TestCase

  def setup
    super
  end

  test "Correctly converts method name to ActiveRecord class" do
    assert_equal Recipe, active_record_class_from_association_method_name("recipes")
    assert_equal Recipe, active_record_class_from_association_method_name("recipes<<")
    assert_equal Recipe, active_record_class_from_association_method_name("recipes=")
    assert_equal Recipe, active_record_class_from_association_method_name("recipe_ids")
    assert_equal Recipe, active_record_class_from_association_method_name("recipe_ids=")
    assert_equal FeedEntry, active_record_class_from_association_method_name("feed_entry_ids=")
    assert_equal FeedEntry, active_record_class_from_association_method_name("feed_entries")
    assert_equal FeedEntry, active_record_class_from_association_method_name("feed_entries=")
  end
end
