# encoding: UTF-8
require 'test_helper'
class ThumbnailTest < ActiveSupport::TestCase 
	
	test "Bad URLs" do
	  thumb =  Thumbnail.acquire("garbage_url", "nopath")
		assert_nil thumb, "Bad URL should produce nil Thumbnail"
	  thumb =  Thumbnail.acquire("htp://www.recipepower.com/url", "nopath")
		assert_nil thumb, "Bad URL should produce nil thumbnail"
	end
		
	test "Same paths should resolve to same thumbnail" do
	  thumb1 =  Thumbnail.acquire("http://local.recipepower.com:3000/assets/index.htm", "aol_64.png")
	  thumb2 =  Thumbnail.acquire("http://local.recipepower.com:3000", "/assets/aol_64.png")
		assert_equal thumb1, thumb2, "Paths with same reference should resolve to same thumbnail"
  end
  
  test "Acquire Nigel Slater" do
    thumb = Thumbnail.acquire "http://www.guardian.co.uk/lifeandstyle/2013/jan/06/nigel-slater-epiphany-cake-recipe",     
        "http://static.guim.co.uk/sys-images/Observer/Pix/pictures/2013/1/2/1357127540095/nigel-slater-rosc-n-de-re-008.jpg"
    assert_equal 0, thumb.thumbdata =~ /^data/
  end
end
