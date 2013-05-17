require 'test_helper'
class ReferentServicesTest < ActiveSupport::TestCase 
  fixtures :referents
  fixtures :referent_relations
  
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
  
end