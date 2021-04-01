require 'test_helper'
class TrackingTest < ActiveSupport::TestCase

  test "basic attributes established in recipe" do
    url = "https://www.theguardian.com/lifeandstyle/2016/mar/12/merguez-recipes-kebab-potato-bake-scotch-egg-yotam-ottolenghi"
    rcp = Recipe.new url: url
    # The recipe should come to life needing its url to be finalized
    # Add that to :title and :description
    rcp.request_attributes :title, :description
    assert_equal [ :title, :description ], rcp.needed_attributes

    rcp.ensure_attributes # Get them all, referring to PageRef as nec.
    assert_empty rcp.needed_attributes
    assert_equal [ :picurl, :title, :description ], rcp.ready_attributes
  end

  test "basic attributes established in PageRef" do
    url = "https://www.theguardian.com/lifeandstyle/2016/mar/12/merguez-recipes-kebab-potato-bake-scotch-egg-yotam-ottolenghi"
    pr = PageRef.fetch url
    # After creation, the :url attribute should be ready but still needed, until Gleaning and MercuryResult are consulted
    assert pr.url_ready?
    assert pr.url_needed?

    # In the beginning, all tracked attributes are open
    assert_equal PageRef.tracked_attributes, pr.open_attributes
    # PageRef is build needing url to be defined by Gleaning and MercuryResult
    assert_equal [ :url ], pr.needed_attributes
    # Get the definitive URL from the Gleaning and/or MercuryResult
    pr.ensure_attributes
    assert_equal [ :url, :domain, :title, :picurl, :date_published, :author, :description, :rss_feeds ], pr.ready_attributes
    assert_empty pr.needed_attributes

  end

  test "recipe page tracks correctly via page ref" do
    url = "https://www.theguardian.com/lifeandstyle/2016/mar/12/merguez-recipes-kebab-potato-bake-scotch-egg-yotam-ottolenghi"
    pr = PageRef.fetch url
    # We create a RecipePage by asking the PageRef for it
    pr.ensure_attributes :recipe_page
    rp = pr.recipe_page
    assert_not_nil rp
    assert pr.content_ready?

    # We parse out the page by asking the RecipePage for its content
    rp.ensure_attributes :content
    assert_equal 3, pr.recipes.to_a.count
  end

  test "recipe gets parsed correctly" do
    url = "https://www.theguardian.com/lifeandstyle/2016/mar/12/merguez-recipes-kebab-potato-bake-scotch-egg-yotam-ottolenghi"
    recipe = Recipe.new url: url
    pr = recipe.page_ref
    # We create a RecipePage by asking the PageRef for it
    recipe.ensure_attributes :content
    rp = pr.recipe_page
    assert_not_nil rp
    assert pr.content_ready?

    assert_equal 3, pr.recipes.to_a.count
    assert recipe.content_ready? # Parsed successfully
    assert_not_empty recipe.description

    recipe.refresh_attributes :content
    assert recipe.content_needed?
    refute recipe.content_ready?
    recipe.refresh_attributes :content, immediate: true # Initiate a re-parse and complete it RIGHT NOW
    assert recipe.content_ready? # Parsed successfully
    refute recipe.content_needed? # Parsed successfully
  end

  test "refresh attributes" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url
    assert_equal [:picurl, :title, :description, :content], Recipe.tracked_attributes
    recipe.title = 'placeholder' # Set title and flip 'ready' bit
    assert recipe.title_ready
    assert recipe.attrib_ready?(:title)
    refute recipe.title_needed

    # Invalidate the title
    recipe.refresh_attributes :title
    assert recipe.title_needed
    refute recipe.title_ready
    # Attributes which NEED to be acquired
    assert_equal [:title], recipe.needed_attributes
    # Attributes which MAY be set, if the opportunity presents
    assert_equal [:picurl, :title, :description, :content], recipe.open_attributes
    assert_equal [:url, :title], recipe.page_ref.needed_attributes
    recipe.title = 'placeholder2' # Set title and flip 'ready' bit

    # Invalidate all the attributes EXCEPT title
    recipe.refresh_attributes except: [ :title ]
    assert_equal recipe.needed_attributes, Recipe.tracked_attributes - [:title]
    assert_equal [:content, :url, :title, :picurl, :recipe_page, :description].sort, recipe.page_ref.needed_attributes.sort
    # assert_equal [:url, :title, :picurl, :description].sort, recipe.page_ref.mercury_result.needed_attributes.sort
    # assert_equal [:url, :title, :picurl, :description].sort, recipe.page_ref.gleaning.needed_attributes.sort

    recipe.ensure_attributes # Get the title, etc.
    assert_empty recipe.needed_attributes
    assert_equal recipe.ready_attributes, Recipe.tracked_attributes
    assert_empty recipe.page_ref.needed_attributes
    assert_empty recipe.page_ref.mercury_result.needed_attributes
    assert_empty recipe.page_ref.gleaning.needed_attributes
  end

  test "basic attribute tracking" do
    url = "http://www.tasteofbeirut.com/persian-cheese-panir/"
    recipe = Recipe.new url: url
    assert_equal [:picurl, :title, :description, :content], Recipe.tracked_attributes
    refute recipe.title_needed
    refute recipe.attrib_needed?(:title)
    refute recipe.title_ready
    refute recipe.attrib_ready?(:title)

    recipe.title = 'placeholder' # Set title and flip 'ready' bit
    assert recipe.title_ready
    assert recipe.attrib_ready?(:title)
    refute recipe.title_needed
    refute recipe.attrib_needed?(:title)
    assert_equal 'placeholder', recipe.title

    recipe.request_attributes :picurl, :title

    recipe.save
    recipe.reload
    assert recipe.title_ready
    refute recipe.title_needed
    assert_equal 'placeholder', recipe.title

    recipe.ensure_attributes :title # Extract from page_ref
    assert recipe.title_ready
    refute recipe.title_needed
    assert_equal 'placeholder', recipe.title

    #recipe.bkg_land
    #assert recipe.page_ref.site
    #recipe.page_ref.site.decorate
    #assert recipe.good?
    #assert_equal 'placeholder', recipe.title  # Immune to gleaning
    #recipe.title = 'replacement'
    #assert_equal 'replacement', recipe.title
  end

end
