require 'test_helper'
require 'page_ref.rb'
class PageRefTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test
=begin
  def test_fail

    fail('Not implemented')
  end
=end

  test "try substitute" do
    url = 'http://www.saveur.com/article/Recipe/Classic-Indian-Samosa'
    mp = PageRef.fetch url
    assert_not_equal 200, mp.http_status
    new_mp = PageRefServices.new(mp).try_substitute 'saveur.com/article/Recipe', 'saveur.com/article/Recipes'
    assert_equal mp, new_mp
    assert_equal [url], new_mp.aliases
    assert_equal 'http://www.saveur.com/article/Recipes/Classic-Indian-Samosa', new_mp.url
  end

  test "try substitute on patijinich" do
    url = 'http://patismexicantable.com/2012/02/lamb-barbacoa-in-adobo.html'
    mp = PageRef.new url: url
    mp.bkg_go
    assert mp.bad?
    new_mp = PageRefServices.new(mp).try_substitute(url, 'https://patijinich.com/recipe/lamb_barbacoa_in_adobo')
    assert_equal mp, new_mp
    assert new_mp.aliases.include?(url)
    assert_equal 'https://patijinich.com/recipe/lamb_barbacoa_in_adobo/', new_mp.url
  end

  test "try substitute absorbs" do
    mpgood = PageRef::RecipePageRef.fetch 'http://www.saveur.com/article/Recipes/Classic-Indian-Samosa'
    mpgood.save
    assert mpgood.good?

    url = 'http://www.saveur.com/article/Recipe/Classic-Indian-Samosa'
    mpbad = PageRef::RecipePageRef.new url: url
    mpbad.bkg_go
    assert mpbad.bad?
    badid = mpbad.id

    new_mp = PageRefServices.new(mpbad).try_substitute 'saveur.com/article/Recipe', 'saveur.com/article/Recipes'
    assert_equal mpgood, new_mp
    assert_equal [url], new_mp.aliases
    assert_nil PageRef.find_by(id: badid)
    assert_equal 'http://www.saveur.com/article/Recipes/Classic-Indian-Samosa', new_mp.url
  end

  test "initializes simple page" do
    url = 'http://smittenkitchen.com/2016/11/brussels-sprouts-apple-and-pomegranate-salad/'
    mp = PageRef.fetch url
    assert_not_nil mp
    assert !mp.errors.any?
    assert_equal Array, mp.aliases.class
    assert_equal ActiveSupport::HashWithIndifferentAccess, mp.extraneity.class
    assert_equal url, mp.url
  end

  test "record persists in database" do
    mp0 = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp0.save
    mp = PageRef.find_by(url: 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/')
    assert_not_nil mp
    assert mp.aliases.empty?
    assert_equal 'An Ode to the Rosetta Spacecraft as It Flings Itself Into a Comet', mp.title
  end

  test "target in URL made irrelevant" do
    mp = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet#target'
    # URL extracted from page
    assert_equal 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/', mp.url
    # Original URL (minus target) is alias for "official" URL
    assert_equal 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet', mp.aliases.first
    # Original URL found both with and without target
    assert_equal mp.id, PageRef.fetch('https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet#target').id
    assert_equal mp.id, PageRef.fetch('https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet').id
  end

  test "calls initialize only once" do
    mp = RecipePageRef.new url: 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp.sync
    mp.content = ''
    mp.save
    mp2 = RecipePageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/#target'
    assert_equal 1, RecipePageRef.count
    assert_equal '', mp.content
  end

  test "page record findable by url" do
    url = 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp = PageRef.fetch url
    mp.save
    assert_not_nil mp.id
    mp2 = PageRef.fetch url
    assert_equal mp, mp2
  end

  test "creation fails with bogus URL" do
    mp = PageRef.fetch 'http://www.mibogus.com/bomb'
    assert !mp.errors.any?
  end

  test "fetch simple page" do
    mp = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    assert_not_nil mp
    assert_equal 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/', mp.url
    assert_equal 'An Ode to the Rosetta Spacecraft as It Flings Itself Into a Comet', mp.title
    assert_equal 'https://www.wired.com/wp-content/uploads/2016/09/Rosetta_impact-1-1200x630.jpg', mp.lead_image_url
    assert_equal 'www.wired.com', mp.domain
    assert_equal 'Time to break out the tissues, space fans.', mp.excerpt
    assert_equal 1031, mp.word_count
    assert_equal 'ltr', mp.direction
    assert_equal 1, mp.total_pages
    assert_equal 1, mp.rendered_pages
    assert_equal 'Emma Grey Ellis', mp.author
  end

  test "catch null byte" do
    mp = PageRef.fetch 'http://www.realsimple.com/food-recipes/ingredients-guide/shrimp-00000000039364/index.html'
    assert_not_nil mp
  end

  test "try this one" do
    mp = PageRef.fetch "http://www.bbc.co.uk/food/recipes/mac_and_cheese_81649"
    assert_not_nil mp
  end

  test "correctly handles HTTP 404 (missing URL)" do
    url = "http://honest-food.net/vejjie-recipes/unusual-garden-veggies/cicerchia-bean-salad/"
    pr = PageRef.fetch url
    assert pr.bad?
    assert_nil pr.id
    # assert !pr.errors.any?

    pr.bkg_go true
    assert pr.bad?
    assert_not_nil pr.id
    assert_equal url, pr.url
  end

  test "gets URL that can be opened, but not by Mercury" do
    url = "http://abcnews.go.com/GMA/recipe/mario-batalis-marinated-olives-15088486"
    pr = PageRef.fetch url
    assert pr.bad?
    # assert !pr.errors.any?
    assert_equal 200, pr.http_status
    assert_equal url, pr.url
  end

  test "follow redirects" do
    url = "http://www.tastebook.com/recipes/1967585-Pork-and-Wild-Mushroom-Ragu-with-Potato-Gnocchi"
    pr = PageRef::RecipePageRef.fetch url
    assert_equal 303, pr.http_status # The last redirect here is bad
    assert pr.bad?
    x=2
  end

  test "funky direct" do
    url = "http://www.finecooking.com/recipes/spicy-red-pepper-cilantro-sauce.aspx"
    pr = PageRef::RecipePageRef.fetch url
    pr.bkg_go
    x=2
  end

  test "Make New DefinitionPageRef" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = PageRefServices.assert_for_referent uri, jal
    ref.reload
    rft = jal.primary_meaning
    refid = rft.id
    assert ref.referents.exists?(id: refid), "Referent wasn't added properly"
  end

  test "Assert Redundant Reference Properly" do
    jal = tags(:jal)
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = PageRefServices.assert_for_referent uri, jal, :Tip
    assert_equal :Tip, ref.typesym, "Reference didn't get type"
    ref2 = PageRefServices.assert_for_referent uri, jal, :Video
    assert_equal :Video, ref2.typesym, "New reference on same url didn't get new type"
    assert_equal 1, ref2.referents.size, "Reference should have one referent"
  end

  test "Referent gets proper reference" do
    jal = tags(:jal)
    rft = Referent.express jal
    uri = "http://www.foodandwine.com/chefs/adam-erace"
    ref = PageRefServices.assert_for_referent uri, rft, :Definition
    assert_equal :Definition, ref.typesym, "Definition typesym not :Definition"
    assert (ref2 = rft.page_refs.first), "Referent didn't get reference"
    assert_equal ref.id, ref2.id, "Referent's reference not ours"
    assert ref.referents.first, "New ref didn't get referent"
    assert_equal ref.referents.first.id, rft.id, "Reference's referent doesn't match"
  end

  test "answers.com behaves correctly" do
    # Unfortunately, Mercury gets fooled by answers.com pages, thinking the url is the home page
    # PageRef.fetch special-cases that (smell!), and here we test it.
    url = "http://www.answers.com/topic/pinch"
    dpr = DefinitionPageRef.fetch url
    assert dpr
    assert_equal url, dpr.url
  end

end