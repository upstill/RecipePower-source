require 'test_helper'
# require 'page_ref.rb'
class BackgroundableTest < ActiveSupport::TestCase

  test 'Can run backgroundable tasks without saving records' do
    r = Recipe.new url: "https://patijinich.com/creamy-poblano-soup/"
    r.ensure_attributes [:title] # No saving beforehand
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
    r.ensure_attributes
    # Check that an error occurred in ensuring :content and :url attributes
    assert r.errors[:content].present?
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

  test 'HTTP 403 error doesnt get re-queued unless virginized' do
    pr = PageRef.fetch 'http://scrapbook.lacolombe.com/2013/02/14/coffee-caramel-macarons/'
    pr.ensure_attributes
    refute pr.persisted?
    pr.save # Also launches--but doesn't, because it's failed prior
    assert pr.persisted?
    refute pr.dj # Didn't re-queue the job because it was run in-process
    pr.bkg_launch true
    assert pr.dj # NOW we're ready to rerun
    pr.bkg_land
    # Should run using DJ, fail with 404 error, then give up because it's a permanent error
    assert pr.bad?
    refute pr.dj
    # Now it won't re-queue the job until forced
    pr.title = 'Changed Title'
    pr.save
    refute pr.dj # Doesn't launch when saved
    pr.bkg_launch
    refute pr.dj # Doesn't launch when asked to (which saving does anyway)
    pr.bkg_launch true

  end

  test 'nonpermanent error gets requeued but not re-executed until time unless forced' do
    url = 'http://www.mariobatali.com/recipes/focaccia-panzanella/'
    pr = PageRef.fetch url
    refute pr.persisted?
    pr.save
    assert pr.dj # Launch on save
    runtime = pr.dj.run_at
    pr.bkg_land
    assert_equal 500, pr.http_status
    assert_not_equal runtime, pr.dj.run_at
  end

end