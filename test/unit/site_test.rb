# encoding: UTF-8
require 'test_helper'
require './lib/uri_utils.rb'

class SiteTest < ActiveSupport::TestCase 
    fixtures :sites
    
    test "Same sample maps to same site" do
        alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"

        site1 = Site.find_or_create alcasample
        site2 = Site.find_or_create alcasample
        assert_equal site1, site2, "Same sample creates different sites"
    end

    test "Different samples from one site map to same site" do
        alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
        site1 = Site.find_or_create(alcasample)
        alcasample = "http://www.alcademics.com/2012/04/the-golden-gate-75-cocktail-.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
        site2 = Site.find_or_create(alcasample)
        assert_equal site1, site2, "Different samples from one site creates different sites"
    end
    
    test "Invalid URLs test invalid" do
      assert_nil valid_url( "nopath", "garbage_url")
      assert_nil valid_url( "nopath", "htp://www.recipepower.com/url")
      assert_nil valid_url( nil, "htp://www.recipepower.com/url")
      assert_nil valid_url( "", "htp://www.recipepower.com/url")
    end
    
    test "Valid URLs test valid" do
      assert_equal "http://www.recipepower.com/url", valid_url( nil, "http://www.recipepower.com/url"), "Nil path doesn't defer to URL"
      assert_equal "http://www.recipepower.com/url", valid_url( "", "http://www.recipepower.com/url"), "Empty path doesn't defer to URL"
      assert_equal "http://www.recipepower.com/assets/nopic", valid_url( "assets/nopic", "http://www.recipepower.com"), "Can't join URL to relative path"
      assert_equal "http://www.recipepower.com/assets/nopic", valid_url( "/assets/nopic", "http://www.recipepower.com"), "Can't join base URL to absolute path"
      assert_equal "http://www.recipepower.com/assets/nopic", valid_url( "/assets/nopic", "http://www.recipepower.com/somethingelse"), "Can't join base URL to absolute path"
      assert_equal "http://www.recipepower.com/assets/nopic", valid_url( "", "http://www.recipepower.com/assets/nopic"), "Path doesn't defer to url"
      assert_equal "http://www.recipepower.com/public/pic2", valid_url( "../public/pic2", "http://www.recipepower.com/assets/nopic"), "Path doesn't defer to url"
    end
    
    test "Paths correctly followed" do
      assert_equal  "http://www.recipepower.com/dir1/dir2/dir3/new.htm", 
                    valid_url( "dir3/new.htm", "http://www.recipepower.com/dir1/dir2/index.htm"), 
                    "Terminating file not dropped"
      assert_equal  "http://www.recipepower.com/dir1/dir2/dir3/new.htm", 
                    valid_url( "dir3/new.htm", "http://www.recipepower.com/dir1/dir2/"), 
                    "Terminating directory dropped"
      assert_equal  "http://www.recipepower.com/dir3/new.htm", 
                    valid_url( "/dir3/new.htm", "http://www.recipepower.com/dir1/dir2/index.htm"), 
                    "Absolute path doesn't descend from site home"
    end
    
    test "Nigel Slater" do
      assert valid_url( "http://static.guim.co.uk/sys-images/Observer/Pix/pictures/2013/1/2/1357127540095/nigel-slater-rosc-n-de-re-008.jpg",
                        "http://www.guardian.co.uk/lifeandstyle/2013/jan/06/nigel-slater-epiphany-cake-recipe")
    end
    
    test "Home page has correct sample and site" do
      site = Site.find_or_create "http://bladebla.com/esme"
      assert_equal "http://bladebla.com/esme", site.sample
      assert_equal "http://bladebla.com/", site.home
    end

  test "Home page established and maintained" do
    site = Site.find_or_create "http://bladebla.com"
    # Should now have two references, the canonical one without the slash, and a second one with
    assert_equal "http://bladebla.com/", site.home
    site.home = "http://bladebla.com"
    assert_equal "http://bladebla.com/", site.home
    site.home = "http://bladebla.com/"
    assert_equal "http://bladebla.com/", site.home
  end


end