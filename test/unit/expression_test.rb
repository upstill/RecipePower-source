# encoding: UTF-8
require 'test_helper'
class ExpressionTest < ActiveSupport::TestCase
  fixtures :referents
  fixtures :tags
  fixtures :expressions

  def setup
    super
  end

  test "Create expression" do

    tagid = tags(:jal).id
    assert tags(:jal).save, "Couldn't save tag"
    jal = Tag.find tagid

    tagid = tags(:jal2).id
    assert tags(:jal2).save, "Couldn't save tag"
    jal2 = Tag.find tagid

    tags(:chilibean_free).destroy
    tagid = tags(:chilibean).id
    assert tags(:chilibean).save, "Couldn't save tag"
    chilibean = Tag.find tagid

    ref = Referent.express jal, locale: :es
    assert_equal "jalapeño peppers", ref.name, "Didn't adopt name when expressed"
    ref.express jal2, form: :plural
    ref.express chilibean, form: :generic, locale: :en

    assert_equal "chili bean", ref.name, "Didn't adopt name when expressed"
    assert_equal "jalapeño peppers", ref.expression(locale: :es).name, "Didn't find Spanish name"
    assert_equal "Chipotle -chiles", ref.expression(form: :plural).name, "Didn't find plural"

  end

  test "Expression Fixtures created correctly" do
    dessert = tags(:dessert)
    assert_equal 1, dessert.meanings.count, "Dessert should only have one referent"
    assert_equal dessert.primary_meaning, dessert.meanings.first, "Dessert should have only its referent's primary meaning"
    assert_equal dessert, dessert.primary_meaning.canonical_expression, "Dessert should be the primary meaning of its referent"

    pie = tags(:pie)
    assert_equal 1, pie.meanings.count, "Pie should only have one referent"
    assert_equal pie.primary_meaning, pie.meanings.first, "Pie should have only its referent's primary meaning"
    assert_equal pie, pie.primary_meaning.canonical_expression, "Pie should be the primary meaning of its referent"

    cake = tags(:cake)
    gateau = tags(:gateau)
    assert_equal 1, cake.meanings.count, "Cake should only have one referent"
    assert_equal cake.primary_meaning, cake.meanings.first, "Cake should have only its referent's primary meaning"
    assert_equal cake, gateau.meaning.expression, "Gateau should be the primary expression of cake"

  end

  test "Synonyms identified correctly" do
    pie = tags(:pie)
    pies = tags(:pies)
    assert_equal ExpressionServices.synonym_ids_of_tags(pie.id)-[pie.id], [pies.id], "Pie should have pies as synonym"
    assert_equal ExpressionServices.synonym_ids_of_tags([pie.id])-[pie.id], [pies.id], "Pie should have pies as synonym when presented as array"

    dessert = tags(:dessert)
    desserts = tags(:desserts)
    assert_equal ExpressionServices.synonym_ids_of_tags(dessert.id)-[dessert.id], [desserts.id], "Dessert should have desserts as synonym"
    assert_equal ExpressionServices.synonym_ids_of_tags([dessert.id])-[dessert.id], [desserts.id], "Dessert should have desserts as synonym when presented as array"

    cake = tags(:cake)
    cakes = tags(:cakes)
    gateau = tags(:gateau)
    cake_syns = ExpressionServices.synonym_ids_of_tags(cake.id) - [cake.id]
    assert cake_syns.include?(cakes.id), "Cake should have cakes as synonym"
    assert cake_syns.include?(gateau.id), "Cake should have gateau as synonym"
    assert_equal 2, cake_syns.count, "Cake should only have two synonyms"
  end

  test "Children identified correctly" do
    pie = tags(:pie)
    pies = tags(:pies)
    dessert = tags(:dessert)
    desserts = tags(:desserts)
    cake = tags(:cake)
    cakes = tags(:cakes)
    gateau = tags(:gateau)
    children = ExpressionServices.child_ids_of_tags(dessert.id)
    assert children.include?(pie.id), "Children of dessert should include pie."
    assert children.include?(pies.id), "Children of dessert should include pies."
    assert children.include?(cake.id), "Children of dessert should include cake."
    assert children.include?(cakes.id), "Children of dessert should include cakes."
    assert children.include?(gateau.id), "Children of dessert should include gateau."
    assert_equal 5, children.count, "Dessert should only have five children."
  end

  test "Parent identified correctly" do
    pie = tags(:pie)
    dessert = tags(:dessert)
    desserts = tags(:desserts)
    parents = ExpressionServices.parent_ids_of_tags(pie.id)
    assert parents.include?(dessert.id), "Parents of pie should include dessert."
    assert parents.include?(desserts.id), "Parents of pie should include dessert."
    assert_equal 2, parents.count, "Pie should have just two parents."
  end

  test "Build a new tag with referent" do
    dessert = Tag.new name: "Mexican", tagtype: 1
    ref = Referent.express dessert # TagServices.new(dessert).assert_referent
    assert dessert.meanings.include?(ref)
    assert ref.tags.include?(dessert)
    assert_equal ref.expression, dessert
    assert_equal dessert.meaning, ref.becomes(Referent)
    ref.reload
    assert_equal 1, ref.expressions.size
    assert_equal 1, ref.tags.size
    dessert.reload
    assert_equal 1, dessert.expressions.size
    assert_equal 1, dessert.meanings.size
  end

  test "Tag added to unsaved referent without saving" do

  end

  test "Two parentless tags synonymize correctly" do
    t1 = tags :jal
    t2 = tags :jal2
    t1.absorb t2, false
    assert_equal t1.meaning, t2.meaning
    assert_equal t1.referent_ids, t2.referent_ids
    assert t1.meaning.is_a?(Referent)
  end

  test "Deleting tag nullifies  in Referent" do

  end

end
