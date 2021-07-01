# encoding: UTF-8
require 'test_helper'
class TaggingTest < ActiveSupport::TestCase
  fixtures :tags
  fixtures :taggings

  def setup
    super
    @tagging1 = Tagging.create id: 1, tag_id: 1, user_id: 1, entity_type: 'Recipe', entity_id: 3
    @tagging2 = Tagging.create id: 2, tag_id: 2, user_id: 1, entity_type: 'Recipe', entity_id: 3
  end

  test "Redirection to redundant tagging is avoided" do
    TaggingServices.change_tag @tagging1.tag_id, @tagging2.tag_id
    assert_nil Tagging.find_by(id: @tagging1.id), "Redirecting tag to existing tag didn't destroy tagging"
  end

  test 'Tagged entities reported' do
    assert_equal tags(:jal), @tagging1.tag
    assert_equal tags(:jal2), @tagging2.tag
    ts = TagServices.new tags(:jal)
    assert_equal 1, ts.taggees.count
    taggee_spec = ts.taggees[Recipe]
    assert_equal 'Just another recipe for testing', taggee_spec.first.title
  end

end
