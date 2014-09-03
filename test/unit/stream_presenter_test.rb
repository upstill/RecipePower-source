require 'test_helper'
class StreamPresenterTest < ActiveSupport::TestCase
  fixtures :sites

  test "ten items stream with single offset" do
    sessionid = "wklejrkjovekj23kjkj3f"
    superklass = ResultsCache
    sp = StreamPresenter.new sessionid, "", IntegersCache, stream: "12"
    assert_equal (12..20).to_a, sp.items
  end

  test "three items stream according to offset" do
    sessionid = "wklejrkjovekj23kjkj3f"
    superklass = ResultsCache
    sp = StreamPresenter.new sessionid, "", IntegersCache, controller: "integers", action: "index", stream: "8-11"
    refute_nil sp.next_range
    assert_equal (8...11).to_a, sp.items
    assert_equal 8, sp.next_item
    assert_equal 9, sp.next_item
    assert_equal 10, sp.next_item
    assert_nil sp.next_item
    assert 11...14, sp.next_range
  end

  test "presenter gets appropriate ResultsCache" do
    sessionid = "wklejrkjovekj23kjkj3f"
    superklass = ResultsCache
    sp = StreamPresenter.new sessionid, "", IntegersCache, controller: "integer", action: "index"
    assert_equal IntegersCache, sp.results.class
    list = List.create
    sp = StreamPresenter.new sessionid, "", ListCache, controller: "list", action: "show", id: list.id
    assert_equal ListCache, sp.results.class

  end

  test "presenter responds correctly for dumping" do
    sessionid = "wklejrkjovekj23kjkj3f"
    superklass = ResultsCache
    sp = StreamPresenter.new sessionid, "", IntegersCache
    refute sp.stream?
    assert sp.dump?
  end

  test "presenter parses existing tag" do
    sessionid = "wklejrkjovekj23kjkj3f"
    t = tags(:jal)
  end
end