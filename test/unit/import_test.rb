# encoding: UTF-8
require 'test_helper'
class ImportTest < ActiveSupport::TestCase 
    
    test "Locales" do
        LinkRef.import_CSVfile "db/data/Test/locales.csv"
      	spice = Referent.express "spice", 4
      	assert_equal 2, spice.tags.size, "'spice' should have two expressions"
      	debugger
      	assert_equal "spice", spice.name
      	assert_equal "épice", spice.name(locale: :fr)
      	assert_equal coconut, coconuts, "'coconut' and 'coconuts' should get the same referent"
    end
    
    test "Coconuts" do
        LinkRef.import_CSVfile "db/data/Test/coconuts.csv"
      	coconut = Referent.express "coconut", 4
      	coconuts = Referent.express "coconuts", 4
      	assert_equal coconut, coconuts, "'coconut' and 'coconuts' should get the same referent"
    end
    
=begin
    test "Anchovies" do
        LinkRef.import_CSVfile "db/data/Test/anchovies.csv"
      	ref = Referent.express "anchovy", 4
      	assert_equal 2, ref.parents.count, "'#{ref.name}' should have two parents"
    end
    
  test "Grapes" do
  	LinkRef.import_CSVfile "db/data/Test/grapes.csv"
  	ref = Referent.express "grape", 4
  	assert_equal 1, ref.children.size, "'grapes' should have one child"
  	child = ref.children.first
  	assert_equal 2, child.expressions.size, "'#{child.name}' should have two expressions"
  	
  	tag = child.tags.last
  	assert_equal 2, tag.links.size, "'#{tag.name}' should have two links"
  	
  end
  
  
  test "Flours" do
	LinkRef.import_CSVfile "db/data/Test/flours.csv"
	
	# Get and test the tag and referent for 'flours'
	flours = Tag.strmatch("flours", tagtype: 4).first
	assert flours, "Couldn't get tag for 'flours'"
	parent = flours.primary_meaning
	assert_equal "flours", parent.name, "flours referent doesn't refer back"
	parent2 = Referent.express "flours", 4
	assert_equal parent.id, parent2.id, "Fetching 'flours' and expressing 'flours' yielded different referents"
	
	# Get and test the tag and referent for 'flours'
	wheat = Tag.strmatch("wheat flour", tagtype: 4).first
	assert wheat, "Couldn't get tag for 'wheat flour'"
	child = wheat.primary_meaning
	assert_equal "wheat flour", child.name, "'wheat flour' referent doesn't refer back"
	child2 = Referent.express "wheat flour", 4
	assert_equal parent.id, parent2.id, "Fetching 'flours' and expressing 'flours' yielded different referents"
	
	assert_equal 5, child2.children.size, "'wheat flour' should have five children"
	
	semolina = Referent.express "semolina flour", 4
	assert_equal "flours/wheat flour/semolina flour", semolina.paths_to[0], "Bad path to 'semolina flour'"
	
	# Read the import file again, confirming no change in number of tags or referents
	ntags_before = Tag.count
	nrefs_before = Referent.count
	nlinks_before = Link.count
	nlinkrefs_before = LinkRef.count
	
	LinkRef.import_CSVfile "db/data/Test/flours.csv"
	
	assert_equal ntags_before, Tag.count, "More tags on second import"
	assert_equal nrefs_before, Referent.count, "More referents on second import"
	assert_equal nlinks_before, Link.count, "More links on second import"
	assert_equal nlinkrefs_before, LinkRef.count, "More link references on second import"
  end
=end
end