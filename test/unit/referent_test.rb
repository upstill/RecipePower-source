# encoding: UTF-8
require 'test_helper'
class ReferentTest < ActiveSupport::TestCase 
    fixtures :referents
    
    test "parent-child relation established" do
        r1 = Referent.create
        r2 = Referent.create
        r1.children << r2
        assert_equal 1, r1.child_ids.count, "Added child, but no child_ids"
        assert_equal r2.id, r1.child_ids.first, "Added child #{r2.id}, but parent only shows #{r1.child_ids.first}"
        assert_equal 1, r2.parent_ids.count, "Added child, but child doesn't list parent"
        assert_equal r1.id, r2.parent_ids.first, "Added child to #{r2.id}, but parent only shows  as #{r1.parent_ids.first}"
    end
    
    test "parent-child relation on GenreReferent subclass established" do
        r1 = GenreReferent.create
        r2 = GenreReferent.create
        r1.children << r2
        assert_equal 1, r1.child_ids.count, "Added child, but no child_ids"
        assert_equal r2.id, r1.child_ids.first, "Added child #{r2.id}, but parent only shows #{r1.child_ids.first}"
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
        r1.children << r2
        assert_equal 1, r1.child_ids.count, "Added child, but no child_ids"
        assert_equal r2.id, r1.child_ids.first, "Added child #{r2.id}, but parent only shows #{r1.child_ids.first}"
        assert_equal 1, r2.parent_ids.count, "Added child, but child doesn't list parent"
        assert_equal r1.id, r2.parent_ids.first, "Added child to #{r2.id}, but parent only shows  as #{r1.parent_ids.first}"
        
        r3 = GenreReferent.find r1.id
        r4 = FoodReferent.find r2.id
        assert_equal 1, r3.child_ids.count, "After find, but no child_ids"
        assert_equal r4.id, r3.child_ids.first, "After find of #{r4.id}, but parent only shows #{r3.child_ids.first}"
        assert_equal 1, r4.parent_ids.count, "After find, child doesn't list parent"
        assert_equal r3.id, r4.parent_ids.first, "After find of #{r4.id}, but parent only shows  as #{r3.parent_ids.first}"
        
        r3 = Referent.find r1.id
        r4 = Referent.find r2.id
        assert_equal 1, r3.child_ids.count, "After find of Referent, but no child_ids"
        assert_equal r4.id, r3.child_ids.first, "After find of Referent #{r4.id}, but parent only shows #{r3.child_ids.first}"
        assert_equal 1, r4.parent_ids.count, "After find of Referent, child doesn't list parent"
        assert_equal r3.id, r4.parent_ids.first, "After find of Referent #{r4.id}, but parent only shows  as #{r3.parent_ids.first}"
        
    end
    
    test "destroying parent doesn't change child" do
        assert_equal 0, ReferentRelation.all.count, "There are ReferentRelations initially"
        r1 = Referent.create
        r2 = Referent.create
        r1.children << r2
        r1.destroy
        r3 = Referent.find r2.id
        assert_equal 0, r3.parents.size, "Destroyed parent #{r1.id}, but child still shows parent #{r3.parent_ids.first}"
        r4 = Referent.create
        r3.parents << r4
        r3.destroy
        assert_equal 0, r4.children.size, "Destroyed child #{r3.id}, but parent #{r4.id} still shows child #{r4.child_ids.first}"
        assert_equal 0, ReferentRelation.all.count, "There are still ReferentRelations after destruction"
    end
    
end