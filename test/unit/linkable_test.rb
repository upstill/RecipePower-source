# encoding: UTF-8
require 'test_helper'
class LinkableTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :tags
  fixtures :recipes

  test "Make New Recipe" do
    rcp = Recipe.find_or_initialize( url: "http://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    assert rcp.errors.empty?, "Recipe should be initialized successfully"
  end
  
  test "Get same recipe twice on the same url" do
    rcp = Recipe.find_or_initialize( url: "http://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    rcp.save
    assert rcp.errors.empty?, "Recipe should be initialized successfully"
    rcp2 = Recipe.find_or_initialize( url: "http://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    assert rcp2.errors.empty?, "Second recipe should be initialized successfully"
    assert_equal rcp.id, rcp2.id, "Recipe should be found twice on the same url"
  end
  
  test "Recipe rejects bad URLs" do
    rcp = Recipe.find_or_initialize( url: "htp://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    assert !rcp.errors.empty?, "Bogus protocol should throw error"
    rcp = Recipe.find_or_initialize( url: "chefs/adam-erace", title: "Some title or other" )
    assert !rcp.errors.empty?, "Relative path in URL should throw error"
    rcp = Recipe.find_or_initialize( url: "Totally bogus URL", title: "Some title or other" )
    assert !rcp.errors.empty?, "Totally bogus URL should throw error"
  end
  
  test "Recipe resolves relative URL" do
    rcp = Recipe.find_or_initialize( url: "/chefs/adam-erace", title: "Some title or other", href: "http://abcnews.com" )
    assert rcp.errors.empty?, "Recipe should accept relative path in presence of href: "+rcp.errors[:url].join("\n\t")
    rcp = Recipe.find_or_initialize( url: "/chefs/adam-erace", title: "Some title or other" )
    assert !rcp.errors.empty?, "Recipe should reject relative path when href not present"
  end
  
end