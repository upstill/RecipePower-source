require 'test_helper'
class ReferentServicesTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :referent_relations
  fixtures :recipes
  fixtures :tags

  def setup
    super
  end

  test "Semantic parenthood set up correctly" do
    dessert = referents(:dessert)
    pie = referents(:pie)
    cake = referents(:cake)
    dessert_pie = referent_relations(:dessert_pie)
    dessert_cake = referent_relations(:dessert_cake)
    assert dessert.child_ids.include?(pie.id), "Pie should be child of dessert"
    assert dessert.child_ids.include?(cake.id), "Cake should be child of dessert"
    assert_equal 2, dessert.child_ids.size, "Dessert should have exactly two children"
  end

  test 'ReferentServices rejects bogus URL' do
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', nil
    assert rft.errors.any?
  end

  test 'ReferentServices rejects invalid internal URL' do
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', 'http://www.recipepower.com/noplace'
    assert rft.errors.any?
  end

  test 'ReferentServices rejects valid internal URL that has no valid entity' do
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', 'http://www.recipepower.com/home'
    assert rft.errors.any?
  end

  test 'ReferentServices rejects internal URL for non-referrable entity' do
    tag = Tag.first
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', "http://www.recipepower.com/tags/#{tag.id}"
    assert rft.errors.any?
  end

  test 'ReferentServices provides errorfree referment when given referrable entity' do
    rcp = Recipe.first
    rft = ReferentServices.new(Referent.first).assert_referment 'Recipe', "http://www.recipepower.com/recipes/#{rcp.id}"
    refute rft.errors.any?
    assert_equal rft.referee, rcp
    rft.referent = Referent.first
    rft.save
    refute rft.errors.any?
  end

end
