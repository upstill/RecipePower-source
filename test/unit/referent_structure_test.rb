# encoding: UTF-8
require 'test_helper'
class ReferentStructureTest < ActiveSupport::TestCase

  test "Successfully creating tags" do
    goat_milk_tag = create :ingredient_tag, name: "goat milk"
    assert_not_nil goat_milk_tag, "Goat Milk Tag not created"
    assert_equal :Ingredient, goat_milk_tag.typesym, "Goat milk tag wrong type"
    assert_equal "goat milk", goat_milk_tag.name, "Goat milk tag wrong name"
    cow_milk_tag = create :tag, name: "cow milk", typenum: 4
  end

  test "Simple Referent" do
    r1 = create :ingredient_referent, name: "goat cheese"
    r2 = create :ingredient_referent, name: "cow cheese"
    p1 = create :ingredient_referent, name: "goat dairy"
    p2 = create :ingredient_referent, name: "milk"
    p3 = create :ingredient_referent, name: "cow dairy"
    c1 = create :ingredient_referent, name: "feta"
    c2 = create :ingredient_referent, name: "chevre"
    c3 = create :ingredient_referent, name: "haloumi"
    c4 = create :ingredient_referent, name: "Fontina"
    c5 = create :ingredient_referent, name: "Emmentaler"
  end

  test "Merge on different types" do
    r1 = create :process_referent, name: "poached"
    assert_equal 3, r1.typenum, "r1 not typed correctly"
    assert_equal "poached", r1.name, "r1 not named correctly"

    r2 = create :ingredient_referent, name: "feta"
    assert_equal 4, r2.typenum, "r2 not typed correctly"
    assert_equal "feta", r2.name, "r2 not named correctly"

    assert_not r1.merge(r2), "Successful merge of two referents of different types"
  end

  test "Tags test" do
    r2 = create :ingredient_referent, name: "cow cheese"

    t2 = r2.canonical_expression
    tags = r2.tags
    exprs = r2.expressions

    assert_equal tags.count, exprs.count, "'#{r2.name}' has mismatch between tags and expressions"
  end

  test "Merge of two referents gets all components" do
    r1 = create :ingredient_referent, name: "goat cheese"
    r2 = create :ingredient_referent, name: "cow cheese", description: "It's me, Cow Cheese!"
    assert_equal "It's me, Cow Cheese!", r2.description, "Description failed to be created"

    t2 = r2.canonical_expression
    puts "r2 is #{r2.class} #{r2.id} with canonical expression ##{r2.canonical_expression.id}"
    puts "t2##{t2.id}'s primary meaning is #{t2.primary_meaning.class}"
    assert_equal t2.primary_meaning, r2, "r2 is not the primary meaning of its canonical expression"
    t1 = r1.canonical_expression
    assert_equal t1.primary_meaning, r1, "r1 is not the primary meaning of its canonical expression"

    p1 = create :ingredient_referent, name: "goat dairy"
    p2 = create :ingredient_referent, name: "milk"
    p3 = create :ingredient_referent, name: "cow dairy"
    c1 = create :ingredient_referent, name: "feta"
    c2 = create :ingredient_referent, name: "chevre"
    c3 = create :ingredient_referent, name: "haloumi"
    c4 = create :ingredient_referent, name: "Fontina"
    c5 = create :ingredient_referent, name: "Emmentaler"
    r1.parents << p1
    r1.parents << p2
    assert_equal 2, r1.parents.count, "wrong # parents"
    r1.children = [c1, c2, c3]
    assert_equal 3, r1.children.count, "wrong # children"
    r1.children << c3
    assert_equal 3, r1.children.count, "successfully added redundant child"

    r2.parents = [p2, p3]
    assert_equal 2, r2.parents.count, "wrong # parents"
    r2.children << c3
    r2.children << c4
    r2.children << c5
    assert_equal 3, r2.children.count, "wrong # children"

    tags = r2.tags
    exprs = r2.expressions
    assert_equal tags.count, exprs.count, "'#{r2.name}' has mismatch between tags and expressions"

    rcp1 = create :recipe
    r1.recipes << rcp1
    assert_equal r1.recipes.first, rcp1, "Recipe not added to referent"
    rcp2 = create :recipe, title: "Poached Eggs with Mint and Yogurt", url: "http://www.nytimes.com/2012/04/04/dining/poached-eggs-with-mint-and-yogurt-recipe.html?partner=rss&emc=rss"
    r2.recipes << rcp2
    assert_equal r2.recipes.first, rcp2, "Recipe not added to referent"

    rfc1 = create :reference
    rfc1.assert r1
    assert_equal r1.references.first, rfc1, "Reference not added to referent"
    assert_equal rfc1.referents.first, r1, "Referent not added to reference"

    rfc2 = create :reference, url: "http://www.foodandwine.com/chefs/adam-frace"
    rfc2.assert r2
    assert_equal r2.references.first, rfc2, "Reference not added to referent"
    assert_equal rfc2.referents.first, r2, "Referent not added to reference"

    ######### Okay, we're all set up. Ready to make changes

    assert_equal "It's me, Cow Cheese!", r2.description, "Description didn't survive"
    r1 = r1.merge(r2)
    assert r1, "Merge failed"
    assert_equal 5, r1.children.count, "wrong # children after merge"
    assert_equal 3, r1.parents.count, "wrong # parents after merge"
    assert_equal 2, r1.expressions.count, "wrong # expressions after merge"
    assert_equal "It's me, Cow Cheese!", r1.description, "Description failed to be merged"
    assert_equal r1.recipes.first, rcp1, "Recipe didn't survive merge"
    assert_equal r1.recipes.last, rcp2, "Recipe didn't make it across merge"
    assert_equal r1.references.first, rfc1, "Reference didn't survive merge"
    assert_equal r1.references.last, rfc2, "Reference didn't make it across merge"
  end

  test "Destroying a referent leaves components untouched" do
    r1 = create :ingredient_referent, name: "goat cheese"
    t1 = r1.canonical_expression
    p1 = create :ingredient_referent, name: "goat dairy"
    p2 = create :ingredient_referent, name: "milk"
    c1 = create :ingredient_referent, name: "feta"
    c2 = create :ingredient_referent, name: "chevre"
    c3 = create :ingredient_referent, name: "haloumi"

    r1.parents << p1
    r1.parents << p2
    assert_equal 2, r1.parents.count, "wrong # parents"
    assert_equal 1, p1.children.count, "parent doesn't have 'goat cheese' as a child"
    assert_equal r1, p1.children.first, "parent doesn't have 'goat cheese' as a child"
    r1.children = [c1, c2, c3]
    assert_equal 3, r1.children.count, "wrong # children"
    assert_equal r1, c1.parents.first, "child doesn't have 'goat cheese' as a parent"
    r1.children << c3
    assert_equal 3, r1.children.count, "successfully added redundant child"

    # Set up recipes
    rcp1 = create :recipe
    r1.recipes << rcp1
    assert_equal r1.recipes.first, rcp1, "Recipe not added to referent"
    rcp2 = create :recipe, title: "Poached Eggs with Mint and Yogurt", url: "http://www.nytimes.com/2012/04/04/dining/poached-eggs-with-mint-and-yogurt-recipe.html?partner=rss&emc=rss"
    r1.recipes << rcp2
    assert_equal r1.recipes.last, rcp2, "Recipe not added to referent"

    # Set up references
    rfc1 = create :reference
    rfc1.assert r1
    assert_equal r1.references.first, rfc1, "Reference not added to referent"
    assert_equal rfc1.referents.first, r1, "Referent not added to reference"

    rfc2 = create :reference, url: "http://www.foodandwine.com/chefs/adam-frace"
    rfc2.assert r1
    assert_equal r1.references.last, rfc2, "Reference not added to referent"
    assert_equal rfc2.referents.first, r1, "Referent not added to reference"

    ########## So much for setup. Now to test results of destruction
    r1.destroy
    assert_equal p1, Referent.find(p1.id), "destroying child destroyed parent"
    assert_equal 0, p1.children.count, "destroying child left parent with dangling child"
    assert_equal c1, Referent.find(c1.id), "destroying parent destroyed child"
    assert_equal 0, c1.parents.count, "destroying parent left child with dangling parent"
    assert_equal t1, Tag.find(t1.id), "destroying referent destroyed tag"
    t1 = Tag.find t1.id # Refresh the tag's meaning
    assert_nil t1.primary_meaning, "tag has dangling primary meaning"
    assert_nil rfc1.referents.first, "Reference has dangling referent after merge"
  end

  test "Destroying referent doesn't leave elements dangling" do

  end

  test "Marge of two referents has the right channel(s)" do

  end

  test "Merge of referents has the right reference(s)" do

  end

  test "Merge of referents has the right recipe(s)" do

  end

  test "Merge of two identical referents shows no change" do

  end

  test "Merge of two referents has appropriate description" do

  end
end