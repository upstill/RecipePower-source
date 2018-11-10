# encoding: UTF-8
require 'test_helper'
class RefermentTest < ActiveSupport::TestCase 
    fixtures :referents
    fixtures :recipes
    fixtures :tags

    test "Referent takes Reference" do
      rft = Referent.express tags(:jal)
      assert (rft.class==IngredientReferent), "Couldn't get referent"
      rfc = ImageReference.create
      assert (rfc.class==ImageReference), "Couldn't get reference"
      rft.image_references << rfc
      assert_equal 1, rft.image_references.count, "Reference not associated with Referent"
      assert_equal 1, rfc.referents.count, "Referent not associated with Reference"
    end
  
    test "Reference takes Referent" do
      rft = Referent.express tags(:jal)
      assert (rft.class==IngredientReferent), "Couldn't get referent"
      rfc = ImageReference.create
      assert (rfc.class==ImageReference), "Couldn't get reference"
      rfc.referents << rft
      assert_equal 1, rft.image_references.count, "Reference not associated with Referent"
      assert_equal 1, rfc.referents.count, "Referent not associated with Reference"
    end
    
    test "Adding Recipe to Referent" do
      rft = Referent.express tags(:jal)
      assert (rft.class==IngredientReferent), "Couldn't get referent"
      rcp = Recipe.first
      assert (rcp.class==Recipe), "Couldn't get recipe"
      rft.recipes << rcp
      assert_equal 1, rft.recipes.count, "Reference not associated with Recipe"
      assert_equal 1, rcp.referents.count, "Referent not associated with Recipe"
    end
  
    test "Adding Referent to Recipe" do
      rft = Referent.express tags(:jal)
      assert (rft.class==IngredientReferent), "Couldn't get referent"
      rcp = Recipe.first
      assert (rcp.class==Recipe), "Couldn't get recipe"
      rcp.referents << rft
      assert_equal 1, rcp.referents.count, "Referent not associated with Recipe"
      assert_equal 1, rft.recipes.count, "Reference not associated with Recipe"
    end
    
end
