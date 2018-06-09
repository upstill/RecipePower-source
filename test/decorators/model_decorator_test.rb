require 'test_helper'

class ModelDecoratorTest < Draper::TestCase
  fixtures :sites
  fixtures :recipes

  test "it gets a site decorator to report out correctly" do
    sdr = sites(:umami1).decorate
    params_in = { name: 'site name', logo: 'site pic url', home: 'site home', description: 'site description', sample: 'site sample'}
    assert_equal 'name', sdr.attribute_for(:title)
    assert_equal 'logo', sdr.attribute_for(:image)
    assert_equal 'home', sdr.attribute_for(:url)
    assert_equal 'description', sdr.attribute_for(:description)
    assert_nil sdr.attribute_for('bogus attribute')
  end

  test "it gets a recipe decorator to report out correctly" do
    rdr = recipes(:rcp).decorate
    assert_equal 'picurl', rdr.attribute_for(:image)
    assert_equal 'description', rdr.attribute_for(:description)
    assert_nil rdr.attribute_for('bogus attribute')
  end

  test "it gets a page_ref decorator to report out correctly" do
    prdr = page_refs(:goodpr).decorate
    assert_equal 'picurl', prdr.attribute_for(:image)
    assert_equal 'description', prdr.attribute_for(:description)
    assert_nil prdr.attribute_for('page_ref_kind')
  end

  test "it translates recipe parameters for page_ref" do
    rdr = recipes(:rcp).decorate
    prdr = page_refs(:goodpr).decorate
    params_in = { picurl: 'some picurl', kind: 'recipe', url: 'some url' }
    params_out = prdr.translate_params_for params_in, page_refs(:goodpr).decorate
    assert_equal params_in, params_out, "No passthrough of translated params for objects of same class"
    params_out = prdr.translate_params_for params_in, recipes(:rcp)
    assert_equal 'some picurl', params_out[:picurl]
    assert_equal 'some picurl', params_out['picurl']
    assert_nil params_out[:kind]
    assert_nil params_out['kind']
  end

  test "it gets site parameters translated for recipe" do
    sdr = sites(:umami1).decorate
    rdr = recipes(:rcp).decorate
    params_in = { name: 'site name', logo: 'site pic url', home: 'site home', description: 'site description', sample: 'site sample'}
    params_out = sdr.translate_params_for params_in, rdr
    assert_equal 'site pic url', params_out[:picurl]
    assert_equal 'site pic url', params_out['picurl']
    assert_equal 'site home', params_out['url']
    assert_equal 'site description', params_out['description']
    assert_nil params_out[:sample]
    assert_nil params_out['sample']
  end

end
