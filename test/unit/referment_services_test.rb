require 'test_helper'
class RefermentServicesTest < ActiveSupport::TestCase
  fixtures :referents
  fixtures :recipes
  fixtures :tags

  def setup
    super
  end

  test 'RefermentServices rejects bogus URL' do
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', nil
    assert rft.errors.any?
  end

  test 'RefermentServices rejects invalid internal URL' do
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', 'http://www.recipepower.com/noplace'
    assert rft.errors.any?
  end

  test 'RefermentServices rejects valid internal URL that has no valid entity' do
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', 'http://www.recipepower.com/home'
    assert rft.errors.any?
  end

  test 'RefermentServices rejects internal URL for non-referrable entity' do
    tag = Tag.first
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', "http://www.recipepower.com/tags/#{tag.id}"
    assert rft.errors.any?
  end

  test 'RefermentServices provides errorfree referment when given referrable entity' do
    rcp = Recipe.first
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', "http://www.recipepower.com/recipes/#{rcp.id}"
    refute rft.errors.any?
    assert_equal rft.referee, rcp
    rft.referent = Referent.first
    rft.save
    refute rft.errors.any?
  end

end
