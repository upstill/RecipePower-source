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
    assert mp.bad?
    new_mp = PageRefServices.new(mp).try_substitute 'saveur.com/article/Recipe', 'saveur.com/article/Recipes'
    assert_equal mp, new_mp
    assert_equal [url], new_mp.aliases
    assert_equal 'http://www.saveur.com/article/Recipes/Classic-Indian-Samosa', new_mp.url
  end

  test "try substitute absorbs" do
    mpgood = PageRef.fetch 'http://www.saveur.com/article/Recipes/Classic-Indian-Samosa'
    assert mpgood.good?

    url = 'http://www.saveur.com/article/Recipe/Classic-Indian-Samosa'
    mpbad = PageRef.fetch url
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
    PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp = PageRef.find_by(url: 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/')
    assert_not_nil mp
    assert_equal 0, mp.aliases.count
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
    mp = PageRef.new url: 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp.sync
    mp.content = ''
    mp.save
    mp2 = PageRef.fetch 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet#target'
    assert_equal 1, PageRef.count
    assert_equal '', mp.content
  end

  test "page record findable by url" do
    url = 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    mp = PageRef.fetch url
    assert_not_nil mp.id
    mp2 = PageRef.fetch url
    assert_equal mp, mp2
  end

  test "creation fails with bogus URL" do
    mp = PageRef.fetch 'http://www.mibogus.com/bomb'
    assert mp.bad?
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
    url = "http://honest-food.net/veggie-recipes/unusual-garden-veggies/cicerchia-bean-salad/"
    pr = PageRef.fetch url
    assert pr.bad?
    assert pr.error_message.present?
    assert_equal url, pr.url
  end

  test "gets URL that can be opened" do
    url = "http://abcnews.go.com/GMA/recipe/mario-batalis-marinated-olives-15088486"
    pr = PageRef.fetch url
    assert pr.bad?
    assert pr.error_message.present?
    assert_equal url, pr.url
  end

  test "creating Site pageref" do
    url = "http://blog.umamimart.com/2011/12/happy-hour-tom-jerry-the-original-winter-cocktail/"
    pr = SitePageRef.fetch url
    assert !pr.errors.any?
    assert pr.good?

    pr.status = 0
    pr.bkg_perform
    assert !pr.errors.any?
    assert pr.good?
  end

end