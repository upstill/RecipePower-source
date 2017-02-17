# encoding: UTF-8
require 'test_helper'
require './lib/uri_utils.rb'

class ResultsCacheTest < ActiveSupport::TestCase
  def setup
    @userid = 4
  end
  # TODO tests for ResultsCache
=begin
  test "Params and cache get saved and restored" do
    sessionid = "wklejrkjovekj23kjkj3f"
    params = { controller: "integers", action: "index" }
    rc = IntegersCache.new session_id: sessionid
    rc.params = params
    assert rc.save
    rc.reload
    assert_equal params, rc.params
    rc.cache = [1,2,3]
    assert rc.save
    rc.reload
    assert_equal [1,2,3], rc.cache
  end

  test "it's possible to overwrite one resultscache with another" do
    sessionid = "wklejrkjovekj23kjkj3f"
    params = { controller: "integers", action: "index" }
    rc1 = IntegersCache.retrieve_or_build sessionid, [], params
    assert rc1.save
    rc2 = IntegersCache.retrieve_or_build sessionid, [], controller: "integers"
    assert rc2.save
    assert_equal rc1.id, rc2.id
    rc = ResultsCache.find [sessionid, "IntegersCache"]
    assert_equal IntegersCache, rc.class
    assert_equal rc2, rc
  end

  test "it creates an IntegersCache according to parameters" do
    sessionid = "wklejrkjovekj23kjkj3f"
    params = { controller: "integers", action: "index" }
    rc = IntegersCache.retrieve_or_build sessionid, [], params
    assert_equal IntegersCache, rc.class
    assert rc.save
    assert_equal 1, IntegersCache.where(session_id: sessionid).count
  end

  test "ResultsCache terminates appropriately" do
    sessionid = "wklejrkjovekj23kjkj3f"
    superklass = ResultsCache
    rc = IntegersCache.retrieve_or_build sessionid, [], controller: "integers", action: "index"

    rc.window = [2,4]
    assert_equal 2, rc.next_item
    assert_equal 3, rc.next_item
    assert_nil rc.next_item
    assert_equal 4..14, rc.next_range

    rc.partition.max_window_size=2
    rc.window = [rc.next_range.min,rc.next_range.max]
    assert_equal 4, rc.next_item
    assert_equal 5, rc.next_item
    assert_nil rc.next_item
    assert_equal 6..8, rc.next_range
  end
=end
end