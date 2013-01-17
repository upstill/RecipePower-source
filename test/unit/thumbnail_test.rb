# encoding: UTF-8
require 'test_helper'
class ThumbnailTest < ActiveSupport::TestCase 
    
  test "Missing Picture" do
		thumb = Thumbnail.acquire("nonsense", nil)
		assert_equal "http://www.recipepower.com/assets/MissingPicture.png", thumb.url, "Nil path should show Missing Picture"
		thumb = Thumbnail.acquire("nonsense", "")
		assert_equal "http://www.recipepower.com/assets/MissingPicture.png", thumb.url, "Nil path should show Missing Picture"
	end
	
	test "Bad URLs" do
	  thumb =  Thumbnail.acquire("garbage_url", "nopath")
		assert_equal "http://www.recipepower.com/assets/BadPicURL.png", thumb.url, "Bad URL should show BadPicURL picture"
	  thumb =  Thumbnail.acquire("htp://www.recipepower.com/url", "nopath")
		assert_equal "http://www.recipepower.com/assets/BadPicURL.png", thumb.url, "Bad URL should show BadPicURL picture"
	end
		
	test "Same paths should resolve to same thumbnail" do
	  thumb1 =  Thumbnail.acquire("garbage_url", "nopath")
	  thumb2 =  Thumbnail.acquire("htp://www.recipepower.com/url", "nopath")
		assert_equal thumb1, thumb2, "Bad URLs should produce same BadPicURL thumb"
	  thumb1 =  Thumbnail.acquire("http://localhost:3000/assets/index.htm", "aol_64.png")
	  thumb2 =  Thumbnail.acquire("http://localhost:3000", "/assets/aol_64.png")
		assert_equal thumb1, thumb2, "Paths with same reference should resolve to same thumbnail"
  end
  
  test "Nigel Slater" do
    debugger
    thumb = Thumbnail.acquire "http://www.guardian.co.uk/lifeandstyle/2013/jan/06/nigel-slater-epiphany-cake-recipe",     
        "http://static.guim.co.uk/sys-images/Observer/Pix/pictures/2013/1/2/1357127540095/nigel-slater-rosc-n-de-re-008.jpg"
    assert_equal 0, url =~ /^data/
    x = 2
  end
end
