require 'test_helper'

class TagTest < ActiveSupport::TestCase
  fixtures :users
  fixtures :referents
  fixtures :tags
  fixtures :recipes

  test 'free tag gets absorbed and vanishes' do
    t1 = tags(:chilibean_free)
    t2 = tags(:chilibean)
    t2.absorb t1
    assert_nil Tag.find_by(id: t1.id)
  end

  test 'free tag gets synonymized to another' do
    t1 = tags(:chilibean_free)
    t2 = tags(:desserts)
    t2.absorb t1, false
    assert t1.reload
    assert_equal t1.tagtype, t2.tagtype
    assert t2.referent_ids.present?
    assert_equal t1.referent_ids, t2.referent_ids
  end

  test 'free tag gets absorbed when synonymized with clashing tag' do
    cakes_free = tags(:cakes_free)
    cakes = tags(:cakes)
    cake = tags(:cake)
    assert cakes.synonyms.include? cake
    assert cake.synonyms.include? cakes
    survivor = cakes.absorb cakes_free, false
    assert_equal survivor, cakes
  end

  test 'free tag gets absorbed when synonymized with identical tag' do
    cakes_free = tags(:cakes_free)
    cakes = tags(:cakes)
    survivor = cakes.absorb cakes_free, false
    assert_equal survivor, cakes
  end

  test 'successfully adds a child' do
    pie = tags(:pie)
    cake = tags(:cake)
    dessert = tags(:dessert)
    assert_equal pie.primary_meaning.parents, cake.primary_meaning.parents
    TagServices.new(cake).make_parent_of pie
    assert_equal 1, pie.referents.count
    assert_equal pie.primary_meaning, pie.referents.first
    assert_equal pie.primary_meaning.parents.first, cake.primary_meaning
  end

  test 'cannot make a tag its own parent' do
    pie = tags(:pie)
    pie = TagServices.new(pie).make_parent_of pie
    assert pie.errors.any?
  end
end