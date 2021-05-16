require 'test_helper'
# require 'page_ref.rb'
class PageRefTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
=begin XXX :goodpr as defined (with bad url) won't pass muster in a PageRef now
  def setup
    prgood = page_refs(:goodpr)
    # Go through the build process
    prgood = PageRef.new prgood.attributes.slice(:id, :url, :title, :picture, :kind)
    prgood.aliases.build url: prgood.url.sub('http:', 'https:')
    prgood.save
  end
=end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Do QA on a valid page_ref
  def assert_good page_ref, needed: [ :picurl, :title ]
    assert_equal 200, page_ref.http_status
    assert page_ref.url_ready
    assert page_ref.http_status_ready
    refute page_ref.errors.any?
    if page_ref.persisted?
      assert page_ref.gleaning
      assert page_ref.mercury_result
      assert_equal needed.sort, page_ref.needed_attributes.sort
      assert page_ref.dj
      if needed.empty?
        # Nothing more needed => dj is done, so it should be gone
        refute page_ref.gleaning.dj
        refute page_ref.mercury_result.dj
      else
        assert page_ref.gleaning.dj
        assert page_ref.mercury_result.dj
      end

      # All background jobs should have been launched, both for the PageRef and its site
      site = page_ref.site
      assert site.persisted?
      assert_equal [ :name, :logo, :rss_feed ].sort, site.needed_attributes.sort
      assert site.dj
      assert site.page_ref.dj
      assert_equal [ :title, :picurl, :rss_feeds ].sort, site.page_ref.needed_attributes.sort
      assert site.page_ref.gleaning.dj
      assert site.page_ref.mercury_result.dj
    end
  end

  def assert_bad page_ref
    assert page_ref.bad?
    refute page_ref.http_status_needed
    refute page_ref.url_needed
    assert page_ref.errors.any?
    refute page_ref.persisted?
    refute page_ref.mercury_result&.persisted?
    refute page_ref.gleaning&.persisted?
    refute page_ref.site
  end

  # Once the page_ref has gathered all attributes, these conditions should pertain:
  def assert_done page_ref
    refute page_ref.bad?
    refute page_ref.errors.any?
    assert_empty page_ref.needed_attributes
    assert_equal 200, page_ref.http_status
  end

  test "follow redirects" do
    url = "https://patijinich.com/recipe/lamb_barbacoa_in_adobo"
    pr = PageRef.fetch url
    assert_not_equal url, pr.url # b/c we followed a redirect to finalize the url
    pr.save
    assert_good pr

    # Now a fetch on the original alias should get the just-saved page_ref
    assert_equal pr.id, PageRef.fetch(url).id
  end

  test 'arel for aliases' do
    url = "https://patijinich.com/recipe/lamb_barbacoa_in_adobo"
    pr = PageRef.fetch url
    pr.save
    url2 = pr.url
    assert_not_equal url, url2, "Redirects should have changed url"

    q = Alias.url_query url
    assert PageRef.joins(:aliases).find_by(q)

    q = Alias.url_query url2
    assert PageRef.joins(:aliases).find_by(q)

  end

  test "try substitute on patijinich" do
    # This URL is bad (400 error)
    bad_url = 'http://patismexicantable.com/2012/02/lamb-barbacoa-in-adobo.html'
    page_ref = PageRef.new url: bad_url
    assert_bad page_ref
    page_ref.errors.clear
    # This url is good, but redirects. We need to ensure that Mercury does its job:
    # -- end up with the redirected URL as the primary one
    # -- ensure that the previous url still has an alias redirecting to the good one
    indirect_url = 'https://patijinich.com/recipe/lamb_barbacoa_in_adobo/'
    page_ref.url = indirect_url
    assert_good page_ref
    assert page_ref.alias_for(bad_url)
    assert_match  /lamb_barbacoa_in_adobo/, page_ref.url
    assert page_ref.alias_for?(bad_url)
    assert page_ref.alias_for?(indirect_url)
    assert_nil page_ref.dj
  end

  # Confirm that PageRef performs appropriately under tracking
  test 'ensure attributes in page ref' do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    pr = PageRef.fetch url
    assert_good pr
    refute pr.title_ready
    assert pr.title_needed
    assert pr.gleaning.title_needed
    assert pr.mercury_result.title_needed
    pr.ensure_attributes [:title]
    # Should have extracted the title
    assert pr.title_ready
    # Should have extracted the description as a side effect
    assert pr.description_ready
  end

  test 'early elision of alias' do
    url = 'http://www.saveur.com/article/Recipe/Classic-Indian-Samosa'
    url2 = 'http://www.saveur.com/article/Recipe/Nouveau-Indian-Samosa'
    mp = PageRef.fetch url
    al = mp.alias_for url2, true
    assert_equal mp.aliases.last, al
    mp.elide_alias url2
    assert_not_equal mp.aliases.last, al
    refute mp.alias_for?( 'http://www.saveur.com/article/Recipe/Nouveau-Indian-Samosa')
  end

  test "try substitute absorbs" do
    mpgood = PageRef.fetch 'https://oaktownspiceshop.com/blogs/recipes/roasted-radicchio-and-squash-salad-with-burrata'
    assert_good mpgood

    url = 'https://oaktownspiceshop.com/blogs/recipe/roasted-radicchio-and-squash-salad-with-burrata'
    mpbad = PageRef.new url: url
    assert mpbad.errors.any?
    assert_equal 404, mpbad.http_status
    refute mpgood.http_status_needed
  end

  test "initializes simple page" do
    url = 'http://smittenkitchen.com/2016/11/brussels-sprouts-apple-and-pomegranate-salad/'
    mp = PageRef.fetch url, http_status: 200
    assert_good mp
    assert_equal url, mp.url # url accepted unchanged
    mp.save
    assert_good mp
    mp.ensure_attributes
    assert_good mp, needed: []
    assert_equal url.sub('http', 'https'), mp.url
    assert_equal 1, mp.aliases.to_a.count
  end

  test "record persists in database" do
    mp0 = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp0.save
    mp = PageRef.find_by(url: 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/')
    assert_good mp

    mp.ensure_attributes [:title]
    assert mp.aliases.present?
    assert_equal 1, mp.aliases.count, 'Should have only one alias'
    assert_equal "An Ode to the Rosetta Spacecraft As It Plummets To Its Death", mp.title
  end

  test "target in URL made irrelevant" do
    mp = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet#target'
    # URL extracted from page
    assert_good mp
    assert_equal 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/', mp.url
    mp.save
    # Original URL (minus target) is alias for "official" URL
    assert_equal 'www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet', mp.aliases.first.url
    # Original URL found both with and without target
    assert_equal mp.id, PageRef.fetch('https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet#target').id
    assert_equal mp.id, PageRef.fetch('https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet').id
    assert_equal mp.id, PageRef.fetch('https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/').id
  end

  test "calls initialize only once" do
    pr = PageRef.new url: 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    pr.kind = :recipe
    pr.ensure_attributes
    pr.save
    assert_equal pr.aliases.first.url, 'www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet'
    pr2 = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/#target'
    pr2.kind = :recipe
    assert_equal pr2, pr
    assert_equal 'Time to break out the tissues, space fans.', pr.description
  end

  test "page record findable by url" do
    url = 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp = PageRef.fetch url
    mp.save
    assert_not_nil mp.id
    mp2 = PageRef.fetch url
    assert_equal mp, mp2
  end

  test "build fails with bogus URL" do
    mp = PageRef.fetch 'http://www.mibogus.com/bomb'
    assert mp.errors.any?
  end

  test "fetch simple page" do
    mp = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    assert_not_nil mp
    mp.ensure_attributes [:title, :domain]
    assert_equal 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/', mp.url
    assert_equal "An Ode to the Rosetta Spacecraft As It Plummets To Its Death", mp.title
    assert_equal "https://media.wired.com/photos/5926b676af95806129f50602/191:100/w_1280,c_limit/Rosetta_impact-1.jpg", mp.picurl
    assert_equal 'www.wired.com', mp.domain
    assert_equal 'Time to break out the tissues, space fans.', mp.mercury_result.description
    assert_operator 600, :<=, mp.mercury_result.word_count
    assert_equal 'ltr', mp.mercury_result.direction
    assert_equal 1, mp.mercury_result.total_pages
    assert_equal 1, mp.mercury_result.rendered_pages
  end

  test "catch null byte" do
    mp = PageRef.fetch 'http://www.realsimple.com/food-recipes/ingredients-guide/shrimp-00000000039364/index.html'
    assert_not_nil mp
  end

  test "try this one" do
    mp = PageRef.fetch "http://www.bbc.co.uk/food/recipes/mac_and_cheese_81649"
    assert_equal 404, mp.http_status
    assert mp.errors[:url].any?
  end

  test "correctly handles HTTP 404 missing URL" do
    url = "https://honest-food.net/vejjie-recipes/unusual-garden-veggies/cicerchia-bean-salad/"
    pr = PageRef.fetch url
    assert_bad pr
    assert_nil pr.id # Record shouldn't be persisted, because it wasn't re-launched
    assert_equal url, pr.url
  end

  test "Make New PageRef" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"

    ref = PageRef.fetch uri
    rft = Referent.express jal
    assert jal.meaning_ids.include?(rft.id)
    assert_equal jal.meanings.first, rft
    assert_equal jal.meaning, rft.becomes(Referent)

    ref.assert_referent rft
    # ref = PageRefServices.assert_for_referent uri, Referent.express(jal)

    ref.kind = :about
    ref.save

    # ref.reload
    rft = ref.referents.first # jal.primary_meaning
    assert rft, "Referent wasn't added properly"
    assert_equal rft.page_refs.about.first, ref
  end

  test "Assert Redundant Reference Properly" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"

    ref = PageRef.fetch uri
    ref.assert_referent Referent.express(jal)
    # ref = PageRefServices.assert_for_referent uri, Referent.express(jal)

    ref.kind = :tip
    assert ref.tip?, "Reference didn't get kind"

    ref2 = PageRef.fetch uri
    ref2.assert_referent Referent.express(jal)
    # ref2 = PageRefServices.assert_for_referent uri, Referent.express(jal)

    ref2.kind = :video
    assert ref2.video?, "New reference on same url didn't get new type"
    assert_equal 1, ref2.referents.size, "Reference should have one referent"
  end

  test "Referent gets proper reference" do
    jal = tags(:jal)
    rft = Referent.express jal
    uri = "http://www.foodandwine.com/chefs/adam-erace"

    ref = PageRef.fetch uri
    ref.assert_referent rft
    # ref = PageRefServices.assert_for_referent uri, rft

    ref.kind = :about
    assert ref.about?, "Definition kind not 'about'"
    assert (ref2 = rft.page_refs.first), "Referent didn't get reference"
    assert_equal ref.id, ref2.id, "Referent's reference not ours"
    assert ref.referents.first, "New ref didn't get referent"
    assert_equal ref.referents.first.id, rft.id, "Reference's referent doesn't match"
  end

  test "answers.com behaves correctly" do
    # Unfortunately, Mercury gets fooled by answers.com pages, thinking the url is the home page
    # PageRef.fetch special-cases that (smell!), and here we test it.
    url = "http://www.answers.com/topic/pinch"
    dpr = PageRef.fetch url
    assert dpr
    assert_equal 'https://www.answers.com/redirectSearch?query=pinch', dpr.url
  end

end
