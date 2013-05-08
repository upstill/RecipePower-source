# encoding: UTF-8
require 'test_helper'
class LinkTest < ActiveSupport::TestCase 
    fixtures :links
    
    # @@TypeToSym = [:none, :vendor, :store, :book, :blog, :rcpsite, :cookingsite, :othersite, :video, :glossary, :recipe]
    # @@TypeToString = ["Untyped Link", "Supplier", "Store Location", "Book", "Blog", "Recipe Site", "Cooking Site", "Other Site", "Video", "Glossary", "Recipe"]
    
    test "resource_type_inDB functions correctly" do
        assert_equal 1, Link.resource_type_inDB(:vendor), "symbol not parsed correctly"
        assert_equal 2, Link.resource_type_inDB("Store Location"), "String not parsed correctly"
        assert_equal 4, Link.resource_type_inDB(4), "Integer type not returned"
    end
    
    test "domain extracted on save" do 
        links(:jal).uri
        link = Link.new( uri: links(:jal).uri, resource_type:links(:jal).resource_type )
        assert_nil link.domain, "Domain field empty before save"
        assert link.save, "Saving link"
        assert_equal "cookthink.com", link.domain, "Domain not saved correctly"
    end
    
    test "correct functioning of typestr and typesym" do
        links(:jal).uri
        link = Link.new( uri: links(:jal).uri, resource_type: links(:jal).resource_type )
        assert_equal "Glossary", link.typestr, "Incorrect interpretation of glossary as string"
        assert_equal :glossary, link.typesym, "Incorrect interpretation of glossary as symbol"
        link.resource_type = nil
        link.save
        assert_equal 0, link.resource_type, "Resource_type of nil type not saved as 0"
        assert_equal "untyped", link.typestr, "Incorrect interpretation of nil type as string"
        assert_equal :none, link.typesym,  "Incorrect interpretation of nil type as symbol"
    end
    
    test "assigning type works for all accepted input types" do
        link = Link.new
        assert_nil link.resource_type, "new link doesn't have nil resource_type"
        link.resource_type = :glossary
        assert_equal 9, link.resource_type, "Failed for ':glossary'"
        link.resource_type = "Glossary"
        assert_equal 9, link.resource_type, "Failed for \"Glossary\""
        link.resource_type = 9
        assert_equal 9, link.resource_type, "Failed for '9'"
    end
    
    test "asserting existing link/type combination returns same entry" do
        link = Link.assert_link( links(:jal).uri, links(:jal).resource_type )
        assert_equal link, Link.assert_link( links(:jal).uri, links(:jal).resource_type ), "Links not the same"
    end
    
    test "asserting existing link but different type returns different entry" do
        link = Link.assert_link( links(:jal).uri, links(:jal).resource_type )
        assert_not_equal link, Link.assert_link( links(:jal).uri, links(:jal).resource_type+1 ), "Links are the same"
    end
    
    test "asserting link with nil type gets resource_type 0" do
        link = Link.assert_link( "http://www.recipepower.com/link1" )
        assert_equal 0, link.resource_type, "Wrong resource type for unspecified type"
    end
    
    test "asserting existing link types null resource_type" do 
        uri = "http://www.recipepower.com/link1"
        link = Link.assert_link( uri )
        assert_equal link, Link.assert_link( uri, 1 ), "Untyped resource not coerced"
    end
    
    test "asserting link w/o type grabs existing typed link" do 
        link = Link.assert_link( links(:jal).uri, links(:jal).resource_type )
        link.save
        assert_equal link, Link.assert_link( links(:jal).uri ), "Unspecified type doesn't get typed link"
    end
end