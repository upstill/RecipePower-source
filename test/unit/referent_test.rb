# encoding: UTF-8
require 'test_helper'
class ReferentTest < ActiveSupport::TestCase 
    fixtures :referents
    fixtures :tags
    
    test "Convert empty parents list to tokens and back again" do
        ref = GenreReferent.create
        # Parents list should be empty
        assert ref.parents.empty?, "Parents of new ref should be empty"
        assert ref.parent_tags.empty?, "Tag tokens for empty parents list shuld be empty"
    end
    
    test "Make token list into a parent by tag number" do
        ref = FoodReferent.create
        tagid = tags(:jal).id
        assert tags(:jal).save, "Couldn't save tag"
        tag = Tag.find tagid
        assert_not_nil tag, "Couldn't fetch tag"
        assert_nil tag.primary_meaning, "Couldn't get tag meaning"
        ref.parent_tokens= "#{tagid}"
        assert_equal 1, ref.parents.size, "Didn't create exactly one parent"
        assert_equal tags(:jal).name, ref.parents.first.name, "Parent's name is wrong"
    end
    
    test "Make token list into a parent by tag name on existing tag" do
        ref = FoodReferent.create
        tagid = tags(:jal).id
        tagname = tags(:jal).name
        ref.parent_tokens= "'#{tagname}'"
        assert_equal 1, ref.parents.size, "Didn't create exactly one parent"
        assert_equal tagname, ref.parents.first.name, "Parent's name is wrong"
    end
    
    test "Make token list into a parent by tag name on new tag" do
        ref = FoodReferent.create
        tagname = "New Tag"
        ref.parent_tokens= "'#{tagname}'"
        assert_equal 1, ref.parents.size, "Didn't create exactly one parent"
        assert_equal tagname, ref.parents.first.name, "Parent's name is wrong"
    end

    test "Create parent tokens and token list" do
        ref = FoodReferent.create
        parent = Referent.express tags(:chilibean).name, ref.typenum
        puts "Got expression for '#{tags(:chilibean).name}'"
        puts "Before adding parent #{parent.name}, parents are: "
            ref.parents.each { |par| puts "\t#{par.name}(#{par.canonical_expression.id})" }
        ref.parents << parent
        puts "After adding, parents are: "
            ref.parents.each { |par| puts "\t#{par.name}(#{par.canonical_expression.id})" }
        pt = ref.parent_tags
        assert_equal 1, pt.count, "Should have a single parent token"
        assert_equal tags(:chilibean).id, pt.first.id, "Parent should be tag of chilibean"
    end

    test "Fail to match referent and token of different types" do
        ref = GenreReferent.create
        tagid = tags(:chilibean).id
        tagname = tags(:chilibean).name
        parent = Referent.express tagname, ref.typenum
        assert_equal parent.typenum, ref.typenum, "Types mismatched"
        assert_not_equal parent.expression.id, tagid, "Ingredient used as parent of "
        ref.parent_tokens= "'#{tagname}'"
        assert_equal parent.id, ref.parents.first.id, "Didn't get same referent for parent"
    end

    test "Create parents list, convert to tokens and back again" do
        ref = FoodReferent.create
        parent1 = Referent.express tags(:jal).name, ref.typenum
        assert_equal tags(:jal).name, parent1.name, "Expression doesn't pan out"
        parent2 = Referent.express tags(:chilibean).name, ref.typenum
        assert_equal tags(:chilibean).name, parent2.name, "Expression doesn't pan out"
        ref.parents = [parent1, parent2]
        pt = ref.parent_tags
        assert_equal 2, pt.count
        assert_equal tags(:jal).id, pt.first["id"], "Didn't keep tag's id: #{pt.first.inspect}"
        assert_equal tags(:chilibean).name, pt.last["name"], "Didn't keep tag's name"
        ptstring = "#{pt.first["id"]}, '#{pt.last["name"]}'"
        ref.parent_tokens= ptstring
        ref.save
        pt = ref.parent_tags
        assert_equal 2, pt.count, "Setting parent tokens failed"
        puts "Back from setting parent_tokens=: "+pt.inspect
        assert pt.find{ |parent| parent["id"] == tags(:jal).id }, "Lost jal id"
        assert pt.find{ |parent| parent["id"] == tags(:chilibean).id }, "Lost chilibean id"
    end
    
    test "Referent doesn't have itself as parent or child" do
        ref = Referent.express tags(:jal).name, 4
        ref.parent_tokens= "'#{tags(:jal).name}'"
        puts "For ref w. ID #{ref.id}: "+ref.parents.inspect
        assert_equal 0, ref.parents.count, "Shouldn't make referent parent of self"
        ref.child_tokens= "'#{tags(:jal).name}'"
        assert_equal 0, ref.children.count, "Shouldn't make referent child of self"
    end
    
    test "Parents and children are unique" do
        ref = FoodReferent.create
        ref.parent_tokens= "#{tags(:jal).id}, '#{tags(:jal).name}'"
        assert_equal 1, ref.parents(true).count, "Two identical parents successfully asserted"
        ref.child_tokens= "#{tags(:chilibean).id}, '#{tags(:chilibean).name}'"
        assert_equal 1, ref.children(true).count, "Two identical children successfully asserted"
    end

    test "parent-child relation established" do
        r1 = FoodReferent.create
        r2 = FoodReferent.create
        r1.children << r2
        assert_equal 1, r1.child_ids.count, "Added child, but no child_ids"
        assert_equal r2.id, r1.child_ids.first, "Added child #{r2.id}, but parent only shows #{r1.child_ids.first}"
        r2.reload
        assert_equal 1, r2.parent_ids.count, "Added child, but child doesn't list parent"
        assert_equal r1.id, r2.parent_ids.first, "Added child to #{r2.id}, but parent only shows  as #{r1.parent_ids.first}"
    end
    
    test "parent-child relation on GenreReferent subclass established" do
        r1 = GenreReferent.create
        r2 = GenreReferent.create
        r1.children << r2
        assert_equal 1, r1.child_ids.count, "Added child, but no child_ids"
        assert_equal r2.id, r1.child_ids.first, "Added child #{r2.id}, but parent only shows #{r1.child_ids.first}"
        r2.reload
        assert_equal 1, r2.parent_ids.count, "Added child, but child doesn't list parent"
        assert_equal r1.id, r2.parent_ids.first, "Added child to #{r2.id}, but parent only shows  as #{r1.parent_ids.first}"
        
        r3 = GenreReferent.find r1.id
        r4 = GenreReferent.find r2.id
        assert_equal 1, r3.child_ids.count, "After find, but no child_ids"
        assert_equal r4.id, r3.child_ids.first, "After find of #{r4.id}, but parent only shows #{r3.child_ids.first}"
        assert_equal 1, r4.parent_ids.count, "After find, child doesn't list parent"
        assert_equal r3.id, r4.parent_ids.first, "After find of #{r4.id}, but parent only shows  as #{r3.parent_ids.first}"
        
    end
    
    test "polymorphic relation on GenreReferent and FoodReferent subclasses established" do
        r1 = GenreReferent.create
        r2 = FoodReferent.create
        begin
            r1.children << r2
        rescue Exception => e
            puts e
        end
        assert_equal 0, r1.child_ids.count, "Added mismatched child, successfully"
        r2.reload
        assert_equal 0, r2.parent_ids.count, "Added mismatched parent, successfully"
    end
    
    test "referent must have a type" do
        assert_nil Referent.create.id, "Successfully created generic referent"
    end
    
    test "destroying parent doesn't change child" do
        assert_equal 0, ReferentRelation.all.count, "There are ReferentRelations initially"
        r1 = Referent.create :type => "FoodReferent"
        puts "r1 created with type #{r1.type}"
        r2 = FoodReferent.create
        puts "r2 created with type #{r2.type}"
        r1.children << r2
        r1.destroy
        r3 = Referent.find r2.id
        assert_equal 0, r3.parents.size, "Destroyed parent #{r1.id}, but child still shows parent #{r3.parent_ids.first}"
        r4 = Referent.create :type => "FoodReferent"
        r3.parents << r4
        r3.destroy
        assert_equal 0, r4.children.size, "Destroyed child #{r3.id}, but parent #{r4.id} still shows child #{r4.child_ids.first}"
        assert_equal 0, ReferentRelation.all.count, "There are still ReferentRelations after destruction"
    end
    
    test "Names, Numbers and Symbols for Types" do
        assert_equal "Referent", Referent.referent_class_for_tagtype(0), "Wrong class for tagtype 0"
        assert_equal "GenreReferent", Referent.referent_class_for_tagtype(1), "Wrong class for tagtype 1"
        assert_equal "RoleReferent", Referent.referent_class_for_tagtype(2), "Wrong class for tagtype 2"
        assert_equal "ProcessReferent", Referent.referent_class_for_tagtype(3), "Wrong class for tagtype 3"
        assert_equal "FoodReferent", Referent.referent_class_for_tagtype(4), "Wrong class for tagtype 4"
        assert_equal "UnitReferent", Referent.referent_class_for_tagtype(5), "Wrong class for tagtype 5"
        assert_equal "SourceReferent", Referent.referent_class_for_tagtype(6), "Wrong class for tagtype 6"
        assert_equal "AuthorReferent", Referent.referent_class_for_tagtype(7), "Wrong class for tagtype 7"
        assert_equal "OccasionReferent", Referent.referent_class_for_tagtype(8), "Wrong class for tagtype 8"
        assert_equal "PantrySectionReferent", Referent.referent_class_for_tagtype(9), "Wrong class for tagtype 9"
        assert_equal "StoreSectionReferent", Referent.referent_class_for_tagtype(10), "Wrong class for tagtype 10"
        assert_equal "InterestReferent", Referent.referent_class_for_tagtype(11), "Wrong class for tagtype 11"
        assert_equal "ToolReferent", Referent.referent_class_for_tagtype(12), "Wrong class for tagtype 12"
        assert_equal "NutrientReferent", Referent.referent_class_for_tagtype(13), "Wrong class for tagtype 13"
        assert_equal "CulinaryTermReferent", Referent.referent_class_for_tagtype(14), "Wrong class for tagtype 14"
        
        ref = GenreReferent.new
        assert_equal "Genre", ref.typename, "Bad Type Name"
        assert_equal :Genre, ref.typesym, "Bad Type Symbol"
        assert_equal 1, ref.typenum, "Bad Type Number"
        
        ref = RoleReferent.new
        assert_equal "Role", ref.typename, "Bad Type Name"
        assert_equal :Role, ref.typesym, "Bad Type Symbol"
        assert_equal 2, ref.typenum, "Bad Type Number"
        
        ref = ProcessReferent.new
        assert_equal "Process", ref.typename, "Bad Type Name"
        assert_equal :Process, ref.typesym, "Bad Type Symbol"
        assert_equal 3, ref.typenum, "Bad Type Number"
        
        ref = FoodReferent.new
        assert_equal "Food", ref.typename, "Bad Type Name"
        assert_equal :Food, ref.typesym, "Bad Type Symbol"
        assert_equal 4, ref.typenum, "Bad Type Number"
        
        ref = UnitReferent.new
        assert_equal "Unit", ref.typename, "Bad Type Name"
        assert_equal :Unit, ref.typesym, "Bad Type Symbol"
        assert_equal 5, ref.typenum, "Bad Type Number"
        
        ref = SourceReferent.new
        assert_equal "Source", ref.typename, "Bad Type Name"
        assert_equal :Source, ref.typesym, "Bad Type Symbol"
        assert_equal 6, ref.typenum, "Bad Type Number"
        
        ref = AuthorReferent.new
        assert_equal "Author", ref.typename, "Bad Type Name"
        assert_equal :Author, ref.typesym, "Bad Type Symbol"
        assert_equal 7, ref.typenum, "Bad Type Number"
        
        ref = OccasionReferent.new
        assert_equal "Occasion", ref.typename, "Bad Type Name"
        assert_equal :Occasion, ref.typesym, "Bad Type Symbol"
        assert_equal 8, ref.typenum, "Bad Type Number"
        
        ref = PantrySectionReferent.new
        assert_equal "Pantry Section", ref.typename, "Bad Type Name"
        assert_equal :PantrySection, ref.typesym, "Bad Type Symbol"
        assert_equal 9, ref.typenum, "Bad Type Number"
        
        ref = StoreSectionReferent.new
        assert_equal "Store Section", ref.typename, "Bad Type Name"
        assert_equal :StoreSection, ref.typesym, "Bad Type Symbol"
        assert_equal 10, ref.typenum, "Bad Type Number"
        
        ref = InterestReferent.new
        assert_equal "Interest", ref.typename, "Bad Type Name"
        assert_equal :Interest, ref.typesym, "Bad Type Symbol"
        assert_equal 11, ref.typenum, "Bad Type Number"
        
        ref = ToolReferent.new
        assert_equal "Tool", ref.typename, "Bad Type Name"
        assert_equal :Tool, ref.typesym, "Bad Type Symbol"
        assert_equal 12, ref.typenum, "Bad Type Number"
        
        ref = NutrientReferent.new
        assert_equal "Nutrient", ref.typename, "Bad Type Name"
        assert_equal :Nutrient, ref.typesym, "Bad Type Symbol"
        assert_equal 13, ref.typenum, "Bad Type Number"
        
        ref = CulinaryTermReferent.new
        assert_equal "Culinary Term", ref.typename, "Bad Type Name"
        assert_equal :CulinaryTerm, ref.typesym, "Bad Type Symbol"
        assert_equal 14, ref.typenum, "Bad Type Number"
        
    end
end