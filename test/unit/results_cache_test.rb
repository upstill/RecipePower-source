# encoding: UTF-8
require 'test_helper'
require './lib/uri_utils.rb'

class ResultsCacheTest < ActiveSupport::TestCase
  test "it saves and restores using session_id" do
    sessionid = "wklejrkjovekj23kjkj3f"
    params = { controller: "integers", action: "index" }
    rc = ResultsCache.new session_id: sessionid
    assert rc.save
    rc2 = ResultsCache.find sessionid
    assert_equal rc, rc2
    rc.params = params
    assert rc.save
    rc.reload
    assert_equal params, rc.params
    rc.cache = [1,2,3]
    assert rc.save
    rc.reload
    assert_equal [1,2,3], rc.cache
  end

  test "it saves and restores IntegersCache using session_id" do
    sessionid = "wklejrkjovekj23kjkj3f"
    params = { controller: "integers", action: "index" }
    rc = IntegersCache.new session_id: sessionid
    assert rc.save
    rc2 = IntegersCache.find sessionid
    assert_equal rc, rc2
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
    rc1 = ResultsCache.new session_id: sessionid, params: params
    assert rc1.save
    rc2 = IntegersCache.new session_id: sessionid, params: { controller: "integers" }
    assert rc2.save
    rc = ResultsCache.find sessionid
    assert_equal rc2, rc
  end

  test "it creates an IntegersCache according to parameters" do
    sessionid = "wklejrkjovekj23kjkj3f"
    params = { controller: "integers", action: "index" }
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "integers", action: "index")
    assert_equal IntegersCache, rc.class
    assert_equal params, rc.params
    assert rc.save
    assert_equal 1, IntegersCache.where(session_id: sessionid).count
  end

  test "ResultsCache terminates appropriately" do
    sessionid = "wklejrkjovekj23kjkj3f"
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "integers", action: "index")
    rc.limit = 7

    rc.window = 2..4
    assert_equal 2, rc.next_item
    assert_equal 3, rc.next_item
    assert_nil rc.next_item
    assert_equal 4..6, rc.next_range

    rc.window = rc.next_range
    assert_equal 4, rc.next_item
    assert_equal 5, rc.next_item
    assert_nil rc.next_item
    assert_equal 6..7, rc.next_range

    rc.window = 6..9
    assert_equal 6, rc.next_item
    assert_nil rc.next_item
    assert_nil rc.next_range

    rc.window = 3..5
    assert_equal 3, rc.next_item
    assert_equal 4, rc.next_item
    assert_nil rc.next_item

    rc.window = 8..10
    assert_nil rc.next_item
    assert_nil rc.next_range
  end

  test "ResultsCaches have correct class" do
    sessionid = "wklejrkjovekj23kjkj3f"
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "integers", action: "index")
    assert_equal IntegersCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "feeds", action: "index")
    assert_equal FeedsCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "feeds", action: "show")
    assert_equal FeedCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "users", action: "index")
    assert_equal UsersCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "user", action: "showowned", owned: "collection")
    assert_equal UserCollectionCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "user", action: "showowned", owned: "lists")
    assert_equal UserListsCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "user", action: "showowned", owned: "recent")
    assert_equal UserRecentCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "lists", action: "index")
    assert_equal ListsCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "lists", action: "show")
    assert_equal ListCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "tags", action: "index")
    assert_equal TagsCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "tags", action: "show")
    assert_equal TagCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "sites", action: "index")
    assert_equal SitesCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "references", action: "index")
    assert_equal ReferencesCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "references", action: "show")
    assert_equal ReferenceCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "referents", action: "index")
    assert_equal ReferentsCache, rc.class
    rc = ResultsCache.retrieve_or_build( sessionid, controller: "referents", action: "show")
    assert_equal ReferentCache, rc.class
  end
end