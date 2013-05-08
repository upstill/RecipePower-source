# encoding: UTF-8
require 'test_helper'
class LinkableTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :tags
  fixtures :recipes

  test "Link New Recipe" do
    rcp = recipes(:rcp)
    rcp.url = "http://www.foodandwine.com/chefs/adam-erace"
    rcp.save
    link = Link.assert rcp.url, rcp
    linked_rcp = link.entity
    assert_equal Recipe, linked_rcp.class, "Link didn't adopt recipe"
    assert_equal rcp.id, linked_rcp.id, "Adopted recipe has different ID"
  end
end