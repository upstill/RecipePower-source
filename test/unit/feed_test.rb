# encoding: UTF-8
require 'test_helper'
class FeedTest < ActiveSupport::TestCase 
    
    # @@TypeToSym = [:none, :vendor, :store, :book, :blog, :rcpsite, :cookingsite, :othersite, :video, :glossary, :recipe]
    # @@TypeToString = ["Untyped Link", "Supplier", "Store Location", "Book", "Blog", "Recipe Site", "Cooking Site", "Other Site", "Video", "Glossary", "Recipe"]
    
    test "ruhlman maps correctly" do
      f1 = Feed.new url: "http://ruhlman.com/feed/"
      f1.save
      assert_equal "Ruhlman", f1.title, "Title not extracted"
      assert_equal "Translating the chef’s craft.", f1.description, "Description not extracted"
      assert_equal "https://ruhlman.com/", f1.site.home, "wrong site extracted"
    end
    
    test "bogus feed fails" do
      f = Feed.new url: "bogus feed"
      assert !f.save, "Bogus feed shouldn't save"
    end
    
end