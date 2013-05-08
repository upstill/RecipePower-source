# encoding: UTF-8
require 'test_helper'
class TypeableTest < ActiveSupport::TestCase 
  fixtures :tags

  test "Test Typenum" do
    assert_equal 4, Tag.typenum(4), "Typenum of 4 failed"
    assert_equal 4, Tag.typenum(:Ingredient), "Typenum of :Ingredient failed"
    assert_equal 4, Tag.typenum("Ingredient"), "Typenum of 'Ingredient' failed"
  end

  test "Test Typesym" do
    assert_equal :Ingredient, Tag.typesym(4), "typesym of 4 failed"
    assert_equal :Ingredient, Tag.typesym(:Ingredient), "typesym of :Ingredient failed"
    assert_equal :Ingredient, Tag.typesym("Ingredient"), "typesym of 'Ingredient' failed"
  end

  test "Test Typename" do
    assert_equal "Ingredient", Tag.typename(4), "typename of 4 failed"
    assert_equal "Ingredient", Tag.typename(:Ingredient), "typename of :Ingredient failed"
    assert_equal "Ingredient", Tag.typename("Ingredient"), "typename of 'Ingredient' failed"
  end
  
  test "Test Typenum in instance" do 
    tag = tags(:jal)
    assert_equal 4, tag.typenum, "Typenum of jalapeno failed"
    assert_equal "Ingredient", tag.typename, "typename of jalapeno failed"
    assert_equal :Ingredient, tag.typesym, "typesym of jalapeno failed"
  end

  test "Setting Type" do
    tag = tags(:jal)
    assert_equal 6, tag.typenum=(6), "Setting typenum to 4 failed"
    tag.typenum = :Source
    assert_equal 6, tag.typenum, "Setting typenum to :Source failed"
    tag.typenum = "Source"
    assert_equal 6, tag.typenum, "Setting typenum to 'Source' failed"
  end
  
  test "matching type" do
    tag = tags(:jal)
    assert tag.typematch, "nil type should match any tag"
    assert tag.typematch(4), "should match type 4"
    assert tag.typematch(:Ingredient), "should match type :Ingredient"
    assert tag.typematch("Ingredient"), "should match type 'Ingredient'"
    assert !tag.typematch(1), "shouldn't match type 1"
    assert !tag.typematch(:Genre), "shouldn't match type :Genre"
    assert !tag.typematch("Genre"), "shouldn't match type 'Genre'"
    assert tag.typematch([1,3,4]), "should match type in array"
    assert !tag.typematch([1,3,5]), "shouldn't match type not in array"
  end
  
end
