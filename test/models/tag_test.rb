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

  test 'free tag disappears when asserted to a type that already has such a tag' do
    chilibean_tag = tags(:chilibean)
    free_tag = tags(:chilibean_free)
    unfree_tag = Tag.assert free_tag, :Ingredient
    assert_equal chilibean_tag, unfree_tag
    refute Tag.find_by(id: free_tag.id)
  end

  test 'ancestor_path_to' do
    pie_tag = tags(:pie)
    pie_ref = pie_tag.meaning
    assert_equal pie_ref, pie_tag.referents.first

    cake_tag = tags(:cake)
    cake_ref = cake_tag.meaning
    assert_equal cake_ref, cake_tag.referents.first

    dessert_tag = tags(:dessert)
    dessert_ref = dessert_tag.meaning
    assert_equal dessert_ref, dessert_tag.referents.first

    refute ReferentServices.new(dessert_ref).ancestor_path_to(pie_ref)

    assert (path = ReferentServices.new(pie_ref).ancestor_path_to(pie_ref))
    assert_equal 1, path.length
    assert_equal pie_ref, path.first

    assert (path = ReferentServices.new(pie_ref).ancestor_path_to(dessert_ref))
    assert_equal 2, path.length
    assert_equal dessert_ref, path.last
    assert_equal pie_ref, path.first

  end

  test 'successfully adds a child' do
    pie_tag = tags(:pie)
    pie_ref = pie_tag.meaning
    assert_equal pie_ref, pie_tag.referents.first
    cake_tag = tags(:cake)
    cake_ref = cake_tag.meaning
    dessert_tag = tags(:dessert)
    dessert_ref = dessert_tag.meaning
    cakes_tag = tags(:cakes)
    free_tag = tags(:cakes_free) # Identical but untyped

    # In the case where an untyped tag gets mapped to the "parent", should act as absorb
    unfree_tag = TagServices.new(cakes_tag).make_parent_of free_tag
    assert_equal unfree_tag, cakes_tag

    TagServices.new(cake_tag).make_parent_of cake_tag
    assert cake_tag.errors.any?, "No error from incorrectly making tag its own parent"
    assert_equal pie_ref.parents, cake_ref.parents
    free_tag = TagServices.new(cake_tag).make_parent_of(free_tag)
    assert free_tag.meaning.parents.to_a.include?(cake_ref)
    assert cake_ref.children.to_a.include?(free_tag.meaning)
  end

  test 'adds a synonym as child' do
    dessert_tag = tags(:dessert)
    dessert_ref = dessert_tag.meaning
    assert_equal dessert_ref, dessert_tag.referents.first

    desserts_tag = tags(:desserts)
    desserts_ref = desserts_tag.meaning
    tag = TagServices.new(desserts_tag).make_parent_of desserts_tag # No no!
    assert_equal tag, desserts_tag
    assert tag.errors.any?
    desserts_tag.reload

    tag = TagServices.new(desserts_tag).make_parent_of dessert_tag # Should add a reference
    assert_equal tag, dessert_tag
    refute tag.errors.any?
    assert dessert_tag.meaning.parents.include?(desserts_ref)

  end

  test 'cannot make a tag its own parent' do
    pie = tags(:pie)
    pie = TagServices.new(pie).make_parent_of pie
    assert pie.errors.any?
  end

  test 'cannot make a tag a parent of one of its ancestors' do
    cake_tag = tags(:cake)
    dessert_tag = tags(:dessert)
    cake_tag = TagServices.new(cake_tag).make_parent_of(dessert_tag)
    assert cake_tag.errors.any?
  end
end