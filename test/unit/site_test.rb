# encoding: UTF-8
require 'test_helper'
require './lib/uri_utils.rb'

class SiteTest < ActiveSupport::TestCase
  fixtures :sites

  def setup
    super
  end

  def land_without_persistence site
    site.ensure_attributes [ :name, :logo ]
    refute site.persisted?
    assert_not_nil site.page_ref
    refute site.page_ref.persisted?
    assert_not_nil site.page_ref.gleaning
    refute site.page_ref.gleaning.persisted?
    assert_not_nil site.page_ref.mercury_result
    refute site.page_ref.mercury_result.persisted?
  end

  def trapped_save entity
    # sleep 5  # Allow the database to settle down
    begin
      entity.save
      return
    rescue Exception => e
      entity.created_at = entity.updated_at = Time.now
    end
    begin
      entity.save
    rescue Exception => e
      raise e
    end
  end

  def land_with_persistence site
    site.ensure_attributes [ :name, :logo ]
    trapped_save site
    assert site.errors.empty?
    assert site.persisted?
    assert_not_nil site.page_ref
    assert site.page_ref.persisted?
    assert site.page_ref.errors.empty?

    assert_not_nil site.page_ref.gleaning
    assert site.page_ref.gleaning.persisted?
    assert site.page_ref.gleaning.errors.empty?

    assert_not_nil site.page_ref.mercury_result
    assert site.page_ref.mercury_result.persisted?
    assert site.page_ref.mercury_result.errors.empty?
  end

  test "site initialized to home" do
    site = Site.find_or_build 'http://mexicocooks.typepad.com/mexico_cooks', root: 'mexicocooks.typepad.com/mexico_cooks'
    land_with_persistence site
    assert_equal 'mexicocooks.typepad.com/mexico_cooks', site.root
    assert_not_nil site.page_ref
  end

  test "site created with no home, then set" do
    site = Site.find_or_build 'https://mexicocooks.typepad.com/mexico_cooks', root: 'mexicocooks.typepad.com/mexico_cooks'
    land_with_persistence site
    unless site.respond_to?(:reference)
      assert_equal 'https://mexicocooks.typepad.com/mexico_cooks', site.home.sub(/\/$/, '')
    end
    assert_not_nil site.page_ref
  end

  test "Same sample maps to same site" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"

    site1 = Site.find_or_build_for alcasample
    land_with_persistence site1
    site2 = Site.find_or_build_for alcasample
    land_with_persistence site2
    assert_equal site1, site2, "Same sample creates different sites"
  end

  test "root reassignment for site works" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"

    site1 = Site.find_or_build_for alcasample
    land_with_persistence site1
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
    assert site.page_refs.pluck(:id).include?(dpr.id)
  end

  test "site can get longer root if compatible" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    dpr = PageRef.fetch alcasample
    dpr.kind = 'about'
    dpr.save
    site = dpr.site
    site.ensure_attributes [ :name, :logo ]
    assert_equal 'www.alcademics.com', site.root
    site.root = 'www.alcademics.com/2012'
    assert_equal 'www.alcademics.com/2012', site.root
    assert_equal site, dpr.site
  end

  test "site handles multiple pageref types" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    site = Site.find_or_build_for alcasample
    site.ensure_attributes
    dpr = PageRef.fetch alcasample
    dpr.kind = 'about'
    dpr.save
    assert_equal site, dpr.site # Should get the same site
    alcasample = "http://www.alcademics.com/2012/04/the-golden-gate-75-cocktail-.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    rpr = PageRef.fetch alcasample
    rpr.kind = 'recipe'
    rpr.save
    assert_equal site, rpr.site
    site.reload
    assert_equal [dpr.id, rpr.id, site.page_ref_id].compact.sort, site.page_ref_ids.sort
    trapped_save site
    assert_equal [dpr.id, rpr.id, site.page_ref_id].compact.sort, site.page_ref_ids.sort
  end

  test "with_subroot_of" do
    nyt = Site.find_or_build_for "https://dinersjournal.blogs.nytimes.com/author/melissa-clark/" # sites(:nyt).save # Trigger DelayedJob
    nyt.save
    assert_not_nil nyt.dj, 'Existing site not marked for gleaning'
    nyt1 = "http://dinersjournal.blogs.nytimes.com/2012/03/23/yeasted-dough-for-a-rustic-tart/?partner=rss&emc=rss"
    # nyt2 = "http://www.nytimes.com/2016/12/13/dining/restaurants-no-tipping-service.html?ref=dining"
    dpr = PageRef.fetch nyt1
    dpr.kind = 'about'
    dpr.save
    assert_equal dpr.site, nyt
    short = dpr.site
    short.reload
    assert_includes short.page_refs.pluck(:id), dpr.id, 'Created PageRef does not get included among its site\'s PageRefs'

    long = Site.create sample: nyt.sample, home: "http://dinersjournal.blogs.nytimes.com/2012", root: "dinersjournal.blogs.nytimes.com/2012"
    long.ensure_attributes
    assert_equal "dinersjournal.blogs.nytimes.com/2012", long.root
    assert_equal short, Site.with_subroot_of(long.root)
    # Check that creating the site with the longer path transferred compatible refs
    assert long.page_refs.to_a.include?(dpr)
  end

  test "aliases traced and established for defunct site" do
    # dinersjournal redirects through www.nytimes.com/section/food to www.nytimes.com/pages/dining/index.html
    nyt1 = "https://dinersjournal.blogs.nytimes.com/author/melissa-clark/"
    dpr1 = PageRef.fetch nyt1
    dpr1.kind = 'about'
    dpr1.save
    site1 = dpr1.site
    site1.ensure_attributes
    assert_equal "dinersjournal.blogs.nytimes.com", site1.root
    assert_equal "https://www.nytimes.com/section/food", site1.home
    assert_includes site1.page_ref.aliases.map(&:url), "www.nytimes.com/pages/dining/index.html"
  end

  test "root lengthening moves entities" do
=begin
    nyt1 = "https://dinersjournal.blogs.nytimes.com/author/melissa-clark/"
    dpr1 = PageRef.fetch nyt1
    dpr1.kind = 'about'
    dpr1.save
    site1 = dpr1.site
    site1.ensure_attributes [ :name ]
    assert_equal "dinersjournal.blogs.nytimes.com", site1.root

    site1.root = "www.nytimes.com/2016"
    assert_not_nil site1.errors.messages[:root] # Can't abandon dpr1

    longer_site = Site.create root: "dinersjournal.blogs.nytimes.com/2012/03"
    dpr1.reload
    assert_equal longer_site, dpr1.site
=end

    nyt1 = "https://www.theguardian.com/us-news/2021/dec/30/colorado-wildfires-evacuations-latest"
    pr1 = PageRef.fetch nyt1
    short_site = pr1.site
    assert_equal "www.theguardian.com", short_site.root
    pr1.save

    nyt2 = "https://www.theguardian.com/us-news/2022/jun/02/coal-slide-colorado-workers-killed-xcel-energy"
    pr2 = PageRef.fetch nyt2
    assert_equal short_site, pr2.site
    pr2.save

    long_site = Site.create sample: nyt2, home: 'https://www.theguardian.com/us-news/2022/jun/02', root: 'www.theguardian.com/us-news/2022/jun/02'
    assert_equal "www.theguardian.com/us-news/2022/jun/02", long_site.root
    pr1.reload
    assert_equal short_site.id, pr1.site_id
    pr2.reload
    assert_equal long_site.id, pr2.site_id

  end

  # Test that the relationship between a page_ref and its site is consistent
  # Providing a site parameter asserts that the given site DOES belong to the page_ref
  def assert_page_ref_correctness page_ref, site=page_ref.site
    assert_equal site, page_ref.site, 'Site not associated with page_ref'
    # The page_ref has a site
    assert_not_nil site
    # The site's page_refs includes the page_ref
    assert site.page_refs.include?(page_ref), "Site misses a page_ref that refers to it"
  end

  def assert_site_correctness site
    # Confirm site and its page_ref point to each other
    sitepr = site.page_ref
    assert_not_nil sitepr
    assert_equal sitepr.site, site
    # site appears on the list of sites for the sitepr
    assert_equal sitepr.sites.first, site
  end

  test "Lengthening path sorts pagerefs appropriately" do
    nyt1 = "https://www.theguardian.com/world/2022/jun/03/devastation-and-defiance-in-ukraine-100-days-of-a-war-that-is-reshaping-europe"
    dpr1 = PageRef.fetch nyt1
    dpr1.kind = 'about'
    dpr1.save
    shorter = dpr1.site
    shorter.reload
    assert_page_ref_correctness dpr1
    assert_site_correctness shorter

    shorter.bkg_land
    assert_equal "www.theguardian.com", shorter.root

    longer = Site.create(root: "www.theguardian.com/world", home: nyt1)
    # Creating a site with a longer path attaches extant matching page_ref to it
    dpr1.reload
    longer.reload
    assert_page_ref_correctness dpr1, longer
    assert_site_correctness longer

    nyt2 = "https://www.theguardian.com/world/video/2022/jun/02/russia-occupying-20-ukraine-territory-says-zelenskiy-video"
    dpr2 = PageRef.fetch nyt2
    assert_nil dpr2.id
    # New PageRef matching longer site gets the site
    longer.reload
    dpr2.save
    assert_page_ref_correctness dpr2, longer

    longer.root = "www.theguardian.com/world/2022"
    longer.save
    # With one site now referring to a longer path, one pageref should retreat to the shorter path,
    # and the other should stay with the longer
    assert_equal "www.theguardian.com/world/2022", longer.root
    dpr1.reload
    assert_equal longer, dpr1.site
    dpr2.reload
    assert_equal shorter, dpr2.site
  end

  test "Different samples from one site map to same site" do
    alcasample = "http://www.alcademics.com/2012/04/a-brilliant-idea-that-didnt-quite-work.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    site1 = Site.find_or_build_for(alcasample)
    land_with_persistence site1

    alcasample = "http://www.alcademics.com/2012/04/the-golden-gate-75-cocktail-.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Alcademics+%28alcademics.com%29"
    site2 = Site.find_or_build_for(alcasample)
    land_with_persistence site2

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

=begin
  NB: This test was built under the assumption that bladebla.com redirects to bladebla.cz, which
  is not true (if it ever was)
  test "Home page has correct sample and site" do
    # bladebla.com redirects to bladebla.cz; this should be reflected in the site and its PageRef
    site = Site.find_or_build_for "http://bladebla.com/esme"
    land_without_persistence site
    # assert_equal 2, site.page_ref.aliases.to_a.count
    site.page_ref.save
    refute site.page_ref.errors.any?, site.page_ref.errors.full_messages.join("\nand ")
    assert_equal 2, site.page_ref.aliases.count # Should have one for the original and one for the final url
    assert_equal "http://bladebla.com/esme", site.sample.sub(/\/$/, '')
    assert_equal "https://bladebla.cz", site.home.sub(/\/$/, '')
    assert_equal 'bladebla.com', site.root
    assert_equal 'bladebla.cz', site.page_ref.site.root

    site2 = Site.find_or_build_for "https://bladebla.cz"
    assert_equal site.page_ref.site, site2
    site = Site.find_or_build_for "http://bladebla.com"
    site.ensure_attributes [ :name, :logo ]
    trapped_save site
    assert_equal site.page_ref, site2.page_ref # The two sites are aliases of one another
  end
=end

=begin
NB: I don't <think> the slash/no-slash distinction still pertains
  test "differentiate between different paths" do
    short = Site.find_or_build_for "http://www.esquire.com/food-drink/index.html"
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
    site = Site.find_or_build_for "http://www.esquire.com/food-drink/index.html"
    land_without_persistence site
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
    site = Site.find_or_build_for "http://www.esquire.com/food-drink/"
    trapped_save site 
    assert site.name_needed
    assert site.logo_needed
    site.ensure_attributes
    assert_equal 0, site.dependent_page_refs.count
    pr = PageRef.fetch 'http://www.esquire.com/food-drink/'
    pr.save
    assert_equal site, pr.site
    assert_equal 1, site.dependent_page_refs.count
    assert_equal (site_count+1), Site.count
  end

  test "standalone gleaning" do
    pr = PageRef.fetch 'http://barbecuebible.com'
    assert pr.gleaning  # Gleaning gets initialized by assigning URL
    gl = pr.gleaning
    assert_equal gl.page_ref, pr
    trapped_save gl
    assert_equal pr.gleaning, gl
    assert gl.dj  
    gl.bkg_land
    refute gl.processing?
  end

  test "site pageref" do
    pr = PageRef.fetch 'http://barbecuebible.com'
    assert_equal pr.site.page_ref, pr # The same page_ref should be used for the site
    assert_equal [:title, :picurl], pr.needed_attributes
    refute pr.dj # Should launch on save
    pr.save
    refute pr.errors.any?, "PageRef can't be saved: #{pr.errors.full_messages}"
    assert pr.dj
    pr.ensure_attributes
    assert pr.good?
    refute pr.processing?
  end

  test "site gleaning" do
    url = 'http://barbecuebible.com/recipe/grilled-venison-loin-with-honey-juniper-and-black-pepper-glaze/'
    site = Site.find_or_build_for url
    assert_equal url, site.sample
    assert_equal 'http://barbecuebible.com', site.home
    assert_equal 'barbecuebible.com', site.root
    # Should have extracted info
    land_without_persistence site
    assert_match /Barbecue/, site.name
  end

  test "recipe gleaning" do
    url = 'http://barbecuebible.com/recipe/grilled-venison-loin-with-honey-juniper-and-black-pepper-glaze/'
    recipe = CollectibleServices.find_or_create url: url, title: 'bbq venison loins'
    refute recipe.errors.present?
    assert recipe.id
    assert (site = recipe.site)
    assert_nil site.name
    site.ensure_attributes
    assert_match /Barbecue/, site.name
  end

  ######## Manipulate grammar_mods

  test 'manipulate grammar mods' do
=begin  Leave this alone until a purpose for recipe_selector= is defined
    s = Site.new
    s.recipe_selector = 'heading h1'
    assert_equal Hash( rp_recipelist: { match: { at_css_match: 'heading h1' } } ), s.grammar_mods

    s.recipe_selector = nil
    assert_equal Hash( rp_recipelist: { match: {  } } ), s.grammar_mods
=end

    s = Site.new
    s.ingline_selector = 'li.ingredient'
    assert_equal 'li.ingredient', s.ingline_selector
    assert_equal Hash( rp_ingline: { :in_css_match => 'li.ingredient' } ), s.grammar_mods
end

end
