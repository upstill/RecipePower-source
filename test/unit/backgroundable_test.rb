require 'test_helper'
# require 'page_ref.rb'
class BackgroundableTest < ActiveSupport::TestCase

  test 'Can run backgroundable tasks without saving records' do
    r = Recipe.new url: "https://patijinich.com/creamy-poblano-soup/"
    r.bkg_land # No saving beforehand
    refute r.persisted?
    assert r.title.present?

    assert (pr = r.page_ref)
    refute pr.persisted?
    assert pr.title.present?

    assert (gl = pr.gleaning)
    refute gl.persisted?
    assert gl.title.present?
  end

  test "Creating recipe with bad URL gets errors back to recipe" do
    r = Recipe.new url: 'https://patijinich.com/2012/05/creamy-poblano-soup.html'
    r.bkg_land
    assert r.errors[:base].present?
    assert r.errors[:url].present?
    assert r.bad?

    assert (pr = r.page_ref)
    refute pr.persisted?
    assert pr.errors[:base].present?
    assert pr.errors[:url].present?
    refute (pr.http_status == 200)
    assert pr.bad?

    assert (gl = pr.gleaning)
    refute gl.persisted?
    assert gl.errors[:base].present?
    assert gl.errors[:url].present?
    assert gl.bad?
  end

end