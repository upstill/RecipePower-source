# encoding: UTF-8
require 'test_helper'
class LinkableTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :tags
  fixtures :recipes

  test "Make New Recipe" do
    rcp = CollectibleServices.find_or_create( url: 'http://www.tasteofbeirut.com/kurdish-bulgur-and-turnip-pilaf-grar-ba-shyallem/', title: "Some title or other" )
    assert rcp.errors.empty?, "Recipe should be initialized successfully"
  end
  
  test "Get same recipe twice on the same url" do
    rcp = CollectibleServices.find_or_create( url: "http://www.tasteofbeirut.com/kurdish-bulgur-and-turnip-pilaf-grar-ba-shyallem/", title: "Some title or other" )
    rcp.save
    assert rcp.errors.empty?, "Recipe should be initialized successfully"
    rcp2 = CollectibleServices.find_or_create( url: "http://www.tasteofbeirut.com/kurdish-bulgur-and-turnip-pilaf-grar-ba-shyallem/", title: "Some title or other" )
    assert rcp2.errors.empty?, "Second recipe should be initialized successfully"
    assert_equal rcp.id, rcp2.id, "Recipe should be found twice on the same url"
  end
  
  test "Recipe rejects bad URLs" do
    rcp = CollectibleServices.find_or_create( url: "htp://www.foodandwine.com/chefs/adam-erace", title: "Some title or other" )
    assert !rcp.errors.empty?, "Bogus protocol should throw error"
    rcp = CollectibleServices.find_or_create( url: "chefs/adam-erace", title: "Some title or other" )
    assert !rcp.errors.empty?, "Relative path in URL should throw error"
    rcp = CollectibleServices.find_or_create( url: "Totally bogus URL", title: "Some title or other" )
    assert !rcp.errors.empty?, "Totally bogus URL should throw error"
  end

end