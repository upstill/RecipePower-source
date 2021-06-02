require 'test_helper'
class GleaningServicesTest < ActiveSupport::TestCase
  fixtures :recipes

  test 'completed gleaning for url' do
    url = 'https://oaktownspiceshop.com/blogs/recipes/roasted-radicchio-and-squash-salad-with-burrata'
    gleaning = GleaningServices.completed_gleaning_for(url, 'Image')
    assert gleaning
    refute gleaning.persisted?
    assert gleaning.page_ref
    refute gleaning.page_ref.persisted?
    assert gleaning.good?
    assert_not_empty gleaning.images
    assert_not_empty gleaning.titles
    assert_not_empty gleaning.descriptions
  end

  test 'completed gleaning for page_ref' do
    pr = PageRef.fetch 'https://oaktownspiceshop.com/blogs/recipes/roasted-radicchio-and-squash-salad-with-burrata'
    gleaning = GleaningServices.completed_gleaning_for(pr, 'Image')
    assert gleaning
    refute gleaning.persisted?
    assert gleaning.good?
    assert gleaning.page_ref
    refute gleaning.page_ref.persisted?
    assert_not_empty gleaning.results_for('Image')
  end

  test 'completed gleaning for recipe' do
    gpr = Recipe.new url: 'https://oaktownspiceshop.com/blogs/recipes/roasted-radicchio-and-squash-salad-with-burrata'
    gleaning = GleaningServices.completed_gleaning_for(gpr, 'Image')
    refute gpr.persisted?
    assert gleaning
    refute gleaning.persisted?
    assert gleaning.page_ref
    refute gleaning.page_ref.persisted?
    assert gleaning.good?
    assert_not_empty gleaning.images
    assert_not_empty gleaning.titles
    assert_not_empty gleaning.descriptions
  end
end