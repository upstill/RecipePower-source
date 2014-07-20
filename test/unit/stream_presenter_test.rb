require 'test_helper'
class StreamPresenterTest < ActiveSupport::TestCase

  test "ten items stream with single offset" do
    sp = StreamPresenter.new stream: "12"
    assert_equal (12..21).to_a, sp.items
  end

  test "three items stream according to offset" do
    sp = StreamPresenter.new stream: "8-11"
    refute_nil sp.next_path
    assert_equal (8...11).to_a, sp.items
    assert_equal 8, sp.next_item
    assert_equal 9, sp.next_item
    assert_equal 10, sp.next_item
    assert_nil sp.next_item
    assert_nil sp.next_path
  end

  test "presenter gets appropriate streamer" do
    sp = StreamPresenter.new
    assert_equal Streamer, sp.streamer.class
    sp = StreamPresenter.new controller: "integer", action: "index"
    assert_equal IntegersStreamer, sp.streamer.class
    sp = StreamPresenter.new controller: "integer", action: "show"
    assert_equal IntegerStreamer, sp.streamer.class

  end

  test "presenter responds correctly for dumping" do
    sp = StreamPresenter.new
    refute sp.stream?
    assert sp.dump?
    assert_nil sp.next_path
  end
end