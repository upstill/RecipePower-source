# encoding: UTF-8
require 'test_helper'
require './lib/uri_utils.rb'

class SiteTest < ActiveSupport::TestCase
  fixtures :sites

  test "site initialized to home" do
    site = Site.find_or_create 'http://mexicocooks.typepad.com/mexico_cooks', root: 'mexicocooks.typepad.com/mexico_cooks'
    site.bkg_land
    assert_equal 'mexicocooks.typepad.com/mexico_cooks', site.root
    assert_not_nil site.page_ref
  end

  test "site created with no home, then set" do
    site = Site.find_or_create 'http://mexicocooks.typepad.com/mexico_cooks', root: 'mexicocooks.typepad.com/mexico_cooks'
    site.bkg_land
    unless site.respond_to?(:reference)
      assert_equal 'http://mexicocooks.typepad.com/mexico_cooks', site.home.sub(/\/$/, '')
    end
    assert_not_nil site.page_ref
  end

  test "Same sample maps to same site" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"

    site1 = Site.find_or_create_for alcasample
    site1.bkg_land
    site2 = Site.find_or_create_for alcasample
    site2.bkg_land
    assert_equal site1, site2, "Same sample creates different sites"
  end

  test "root reassignment for site works" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"

    site1 = Site.find_or_create_for alcasample
    site1.bkg_land
    assert_equal 'www.alcademics.com', site1.root
    site1.root = 'www.alcademics.com/2012'
    assert_equal 'www.alcademics.com/2012', site1.root
    site1.root = 'www.alcademics.com/2012/'
    assert_equal 'www.alcademics.com/2012', site1.root
  end

  test "PageRef has site that refers back to it" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    dpr = PageRef.fetch alcasample
    dpr.kind = 'about'
    dpr.save
    site = dpr.site
    assert_not_nil site
    site.reload
    assert_equal dpr, site.page_refs.first
  end

  test "site can get longer root if compatible" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    dpr = PageRef.fetch alcasample
    dpr.kind = 'about'
    dpr.save
    site = dpr.site
    site.bkg_land
    assert_equal 'www.alcademics.com', site.root
    site.root = 'www.alcademics.com/2012'
    assert_equal 'www.alcademics.com/2012', site.root
    assert_equal site, dpr.site
  end

  test "bogus change in site root gets caught" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    dpr = PageRef.fetch alcasample
    dpr.save
    site = dpr.site
    site.bkg_land
    assert_equal 'www.alcademics.com', site.root
    site.root = 'www.alcademics.com/2014'
    assert site.errors.any?
    assert_equal 'www.alcademics.com', site.root
  end

  test "site handles multiple pageref types" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    site = Site.find_or_create_for(alcasample)
    site.bkg_land
    dpr = PageRef.fetch alcasample
    dpr.kind = 'about'
    dpr.save
    assert_equal site, dpr.site # Should get the same site
    alcasample = "http://www.alcademics.com/2012/04/the-golden-gate-75-cocktail-.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    rpr = PageRef.fetch alcasample
    rpr.kind = 'recipe'
    rpr.save
    assert_equal site, rpr.site
    assert_equal [dpr.id, rpr.id, site.page_ref_id].sort, site.page_ref_ids.sort
    site.save
    assert_equal [dpr.id, rpr.id, site.page_ref_id].sort, site.page_ref_ids.sort
  end

  test "with_subroot_of" do
    nyt1 = "http://dinersjournal.blogs.nytimes.com/2012/03/23/yeasted-dough-for-a-rustic-tart/?partner=rss&emc=rss"
    nyt2 = "http://www.nytimes.com/2016/12/13/dining/restaurants-no-tipping-service.html?ref=dining"
    dpr = PageRef.fetch nyt1
    dpr.kind = 'about'
    dpr.save
    short = dpr.site
    short.bkg_land
    long = Site.create(root: "dinersjournal.blogs.nytimes.com/2012", sample: "http://www.alcademics.com/2012", home: "http://www.alcademics.com/2012")
    long.bkg_land
    assert_equal "dinersjournal.blogs.nytimes.com/2012", long.root
    assert_equal short, Site.with_subroot_of(long.root)
    # Check that creating the site with the longer path transferred compatible refs
    assert_equal dpr, long.page_refs.first
  end

  test "root lengthening moves entities" do
    nyt1 = "http://dinersjournal.blogs.nytimes.com/2012/03/23/yeasted-dough-for-a-rustic-tart/?partner=rss&emc=rss"
    dpr1 = PageRef.fetch nyt1
    dpr1.kind = 'about'
    dpr1.save
    site1 = dpr1.site
    site1.bkg_land
    assert_equal "dinersjournal.blogs.nytimes.com", site1.root

    site1.root = "www.nytimes.com/2016"
    assert_not_nil site1.errors.messages[:root] # Can't abandon dpr1

    longer_site = Site.create root: "dinersjournal.blogs.nytimes.com/2012/03"
    dpr1.reload
    assert_equal longer_site, dpr1.site

    nyt2 = "http://www.nytimes.com/2016/12/13/dining/restaurants-no-tipping-service.html?ref=dining"
    dpr2 = PageRef.fetch nyt2
    dpr1.kind = 'about'
    dpr2.save
    site2 = dpr2.site
    assert_equal "www.nytimes.com", site2.root

  end

  test "Lengthening path sorts pagerefs appropriately" do
    nyt1 = "http://www.nytimes.com/2015/08/24/business/economy/as-minimum-wage-rises-restaurants-say-no-to-tips-yes-to-higher-prices.html"
    dpr1 = PageRef.fetch nyt1
    dpr1.kind = 'about'
    dpr1.save
    site1 = dpr1.site
    site1.bkg_land
    assert_equal "www.nytimes.com", site1.root

    longer = Site.create(root: "www.nytimes.com/2015")
    longer.bkg_land
    dpr1.reload
    assert_equal longer, dpr1.site

    nyt2 = "http://www.nytimes.com/2015/10/15/dining/danny-meyer-restaurants-no-tips.html"
    dpr2 = PageRef.fetch nyt2
    dpr2.kind = 'about'
    dpr2.save
    dpr2.site.bkg_land
    assert_equal longer, dpr2.site

    longer.root = "www.nytimes.com/2015/08"
    longer.save
    # With one site now referring to a longer path, one pageref should retreat to the shorter path,
    # and the other should stay with the longer
    assert_equal "www.nytimes.com/2015/08", longer.root
    dpr1.reload
    assert_equal longer, dpr1.site
    dpr2.reload
    assert_equal site1, dpr2.site

  end

  test "Different samples from one site map to same site" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    site1 = Site.find_or_create_for(alcasample)
    site1.bkg_land
    alcasample = "http://www.alcademics.com/2012/04/the-golden-gate-75-cocktail-.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    site2 = Site.find_or_create_for(alcasample)
    site2.bkg_land
    assert_equal site1, site2, "Different samples from one site creates different sites"
  end

  test "Invalid URLs test invalid" do
    assert_nil valid_url("nopath", "garbage_url")
    assert_nil valid_url("nopath", "htp://www.recipepower.com/url")
    assert_nil valid_url(nil, "htp://www.recipepower.com/url")
    assert_nil valid_url("", "htp://www.recipepower.com/url")
  end

  test "Valid URLs test valid" do
    assert_equal "http://www.recipepower.com/url", valid_url(nil, "http://www.recipepower.com/url"), "Nil path doesn't defer to URL"
    assert_equal "http://www.recipepower.com/url", valid_url("", "http://www.recipepower.com/url"), "Empty path doesn't defer to URL"
    assert_equal "http://www.recipepower.com/assets/nopic", valid_url("assets/nopic", "http://www.recipepower.com"), "Can't join URL to relative path"
    assert_equal "http://www.recipepower.com/assets/nopic", valid_url("/assets/nopic", "http://www.recipepower.com"), "Can't join base URL to absolute path"
    assert_equal "http://www.recipepower.com/assets/nopic", valid_url("/assets/nopic", "http://www.recipepower.com/somethingelse"), "Can't join base URL to absolute path"
    assert_equal "http://www.recipepower.com/assets/nopic", valid_url("", "http://www.recipepower.com/assets/nopic"), "Path doesn't defer to url"
    assert_equal "http://www.recipepower.com/public/pic2", valid_url("../public/pic2", "http://www.recipepower.com/assets/nopic"), "Path doesn't defer to url"
  end

  test "Paths correctly followed" do
    assert_equal "http://www.recipepower.com/dir1/dir2/dir3/new.htm",
                 valid_url("dir3/new.htm", "http://www.recipepower.com/dir1/dir2/index.htm"),
                 "Terminating file not dropped"
    assert_equal "http://www.recipepower.com/dir1/dir2/dir3/new.htm",
                 valid_url("dir3/new.htm", "http://www.recipepower.com/dir1/dir2/"),
                 "Terminating directory dropped"
    assert_equal "http://www.recipepower.com/dir3/new.htm",
                 valid_url("/dir3/new.htm", "http://www.recipepower.com/dir1/dir2/index.htm"),
                 "Absolute path doesn't descend from site home"
  end

  test "Nigel Slater" do
    assert valid_url("http://static.guim.co.uk/sys-images/Observer/Pix/pictures/2013/1/2/1357127540095/nigel-slater-rosc-n-de-re-008.jpg",
                     "http://www.guardian.co.uk/lifeandstyle/2013/jan/06/nigel-slater-epiphany-cake-recipe")
  end

  test "Home page has correct sample and site" do
    site = Site.find_or_create_for "http://bladebla.com/esme"
    site.bkg_land
    assert_equal "http://bladebla.com/esme", site.sample.sub(/\/$/, '')
    assert_equal "http://bladebla.com", site.home.sub(/\/$/, '')
  end

  test "Home page established and maintained" do
    site = Site.find_or_create_for "http://bladebla.com/food-and-drink/index.html"
    site.bkg_land
    # Should now have two references, the canonical one without the slash, and a second one with
    assert_equal "http://bladebla.com", site.home.sub(/\/$/, '')
    assert_equal "bladebla.com", site.root
    site.home = "http://bladebla.com"
    assert_equal "http://bladebla.com", site.home.sub(/\/$/, '')
    assert_equal "bladebla.com", site.root
    site.home = "http://bladebla.com/food-and-drink/index.html"
    unless site.respond_to? :reference
      assert_equal "http://bladebla.com/food-and-drink/index.html", site.home.sub(/\/$/, '')
    end
    assert_equal "bladebla.com", site.root
  end

=begin
NB: I don't <think> the slash/no-slash distinction still pertains
  test "differentiate between different paths" do
    short = Site.find_or_create_for "http://www.esquire.com/food-drink/index.html"
    # Should now have two references, the canonical one without the slash, and a second one with
    assert_equal "http://www.esquire.com/", short.home
    assert short.page_ref
    if short.respond_to?(:reference) && short.reference
      assert_equal short.page_ref.url.sub(/\/$/, ''), short.reference.url.sub(/\/$/, '') # Elide the trailing slash for testing
    end
    assert_equal "www.esquire.com", short.root

    long = Site.find_or_create "http://www.esquire.com/food-drink"
    # Should now have two references, the canonical one without the slash, and a second one with
    assert_equal "http://www.esquire.com/food-drink/", long.page_ref.url
    assert_equal "www.esquire.com/food-drink", long.root

  end
=end

  test "reset the home path and root independently" do
    site = Site.find_or_create_for "http://www.esquire.com/food-drink/index.html"
    site.bkg_land
    # Should now have two references, the canonical one without the slash, and a second one with
    assert_equal "https://www.esquire.com", site.home.sub(/\/$/, '')
    assert_equal "www.esquire.com", site.root.sub(/\/$/, '')

    site.root = "www.esquire.com/food-drink"
    # Should now have two references, the canonical one without the slash, and a second one with
    assert_equal "https://www.esquire.com", site.home.sub(/\/$/, '')
    assert_equal "www.esquire.com/food-drink", site.root.sub(/\/$/, '')

    site.home = "https://www.esquire.com/food-drink"
    # Should now have two references, the canonical one without the slash, and a second one with
    unless site.respond_to? :reference
      assert_equal "https://www.esquire.com/food-drink", site.home.sub(/\/$/, '')
    end
    assert_equal "www.esquire.com/food-drink", site.root.sub(/\/$/, '')
  end

  test "associations" do
    site_count = Site.count
    site = Site.find_or_create_for "http://www.esquire.com/food-drink/"
    site.bkg_land
    assert_equal 0, site.dependent_page_refs.count
    pr = PageRef.fetch 'http://www.esquire.com/food-drink/'
    pr.save
    assert_equal 1, site.dependent_page_refs.count
    assert_equal (site_count+1), Site.count
  end

  test "standalone gleaning" do
    pr = PageRef.fetch 'http://barbecuebible.com'
    refute pr.gleaning
    gl = pr.create_gleaning
    assert_equal gl.page_ref, pr
    gl.bkg_launch
    assert gl.dj
    gl.bkg_land
    refute gl.processing?
  end

  test "site pageref" do
    pr = PageRef.fetch 'http://barbecuebible.com'
    pr.bkg_launch
    assert pr.dj
    pr.bkg_land
    refute pr.processing?
  end

  test "site gleaning" do
    site = Site.find_or_create_for 'http://barbecuebible.com/recipe/grilled-venison-loin-with-honey-juniper-and-black-pepper-glaze/'
    # Should have extracted info
    site.bkg_land
    assert_equal 'Barbecuebible.com', site.name
  end

  test "recipe gleaning" do
    url = 'http://barbecuebible.com/recipe/grilled-venison-loin-with-honey-juniper-and-black-pepper-glaze/'
    recipe = CollectibleServices.find_or_create url: url, title: 'bbq venison loins'
    refute recipe.errors.any?
    assert recipe.id
    assert (site = recipe.site)
    assert_nil site.name
    site.bkg_land
    assert_equal 'Barbecuebible.com', site.name
  end

end
