# encoding: UTF-8
require 'test_helper'
class RecipeUserTest < ActiveSupport::TestCase 
    fixtures :recipes
    
    test "Save failure on bad pic URL" do
      success = recipes(:badpicrcp).save
      assert !success, "Recipe with bad pic shouldn't be saved"
      assert recipes(:badpicrcp).thumbnail.bad_url?, "Recipe with bad pic url should get bad_url thumbnail"
    end
    
    test "Save success with good pic URL" do
      success = recipes(:goodpicrcp).save
      assert success, "Recipe with good pic should be saved"
    end
    
    test "Recipe with no picture gets MissingPicture thumbnail" do
      recipes(:rcp).save
      assert recipes(:rcp).thumbnail.missing_picture? , "Didn't get 'no picture' thumb"
    end
end
