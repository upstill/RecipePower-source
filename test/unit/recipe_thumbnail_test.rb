# encoding: UTF-8
require 'test_helper'
class RecipeThumbnailTest < ActiveSupport::TestCase 
  fixtures :recipes
  
  test "Bad pic URL gets bad_url thumbnail" do
    bpr = recipes(:badpicrcp)
    bpr.url = "htp://www.recipepower.com/rcp1"
    bpr.picurl = "assets/absent.png"
    bpr.picture.bkg_land
    assert bpr.picture.bad?, "Recipe with bad pic url should come back bad"
  end
  
  test "Save success with good pic URL" do
    gpr = Recipe.new(title: 'Recipe with Good Picture') # recipes(:goodpicrcp)
    gpr.page_ref = PageRef.new(url_and_status: ["http://www.recipepower.com/rcp1", 404 ] )
    gpr.picurl = 'https://static01.nyt.com/images/2014/06/06/dining/tortilla/tortilla-superJumbo.jpg' # 'assets/MissingLogo.png' # "assets/MissingLogo.png"
    assert_not_nil gpr.picture, "Should have a picture reference for valid URL"
    success = gpr.save
    assert success, "Recipe with pic should be saved"
    gpr.picture.bkg_land
    assert_not_nil gpr.picture.thumbdata, "Should get data for good image"
  end
  
end
