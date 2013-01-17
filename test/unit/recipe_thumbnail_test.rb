# encoding: UTF-8
require 'test_helper'
class RecipeUserTest < ActiveSupport::TestCase 
    fixtures :recipes
    
    test "Save failure on bad pic URL" do
      success = recipes(:badpicrcp).save
      debugger
      assert !success, "Recipe with bad pic shouldn't be saved"
    end
    
    test "Save success with good pic URL" do
      success = recipes(:goodpicrcp).save
      assert success, "Recipe with good pic should be saved"
    end
    
    test "Recipe with no picture gets MissingPicture thumbnail" do
      recipes(:rcp).save
      assert recipes(:rcp).thumbnail.missingPicture? , "Didn't get 'no picture' thumb"
    end
end
