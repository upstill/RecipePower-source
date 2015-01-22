require 'test_helper'

class DeferredRequestTest < ActiveSupport::TestCase

  test "Returns nil before requests registered" do
    assert_nil DeferredRequest.pending( "abcde")
    assert_nil DeferredRequest.pop( "abcde")
  end

  test "Pushes and pops one request" do
    elements = { hello: "world" }
    DeferredRequest.push "abcde", elements
    assert_equal elements, DeferredRequest.pending("abcde")
    assert_equal elements, DeferredRequest.pending("abcde")
    assert_equal elements, DeferredRequest.pending("abcde")
    assert_equal elements, DeferredRequest.pop("abcde")
    assert_nil DeferredRequest.find_by(session_id: "abcde")
    assert_nil DeferredRequest.pending( "abcde")
    assert_nil DeferredRequest.pop( "abcde")
  end

  test "Pushes and pops two requests" do
    elements1 = { hello: "world" }
    elements2 = { goodbye: "cruel world" }
    DeferredRequest.push "abcde", elements1
    DeferredRequest.push "abcde", elements2
    assert_equal elements2, DeferredRequest.pending("abcde")
    assert_equal elements2, DeferredRequest.pending("abcde")
    assert_equal elements2, DeferredRequest.pending("abcde")
    assert_equal elements2, DeferredRequest.pop("abcde")
    assert_equal elements1, DeferredRequest.pending("abcde")
    assert_equal elements1, DeferredRequest.pending("abcde")
    assert_equal elements1, DeferredRequest.pending("abcde")
    assert_equal elements1, DeferredRequest.pop("abcde")
    assert_nil DeferredRequest.find_by(session_id: "abcde")
    assert_nil DeferredRequest.pending( "abcde")
    assert_nil DeferredRequest.pop( "abcde")
  end

  test "depends on session id" do
    elements = { hello: "world" }
    DeferredRequest.push "abcde", elements
    assert_nil DeferredRequest.find_by(session_id: "edcba")
    assert_nil DeferredRequest.pending( "edcba")
    assert_nil DeferredRequest.pop( "edcba")
  end

end
