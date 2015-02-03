require 'test/unit'
require 'test_helper'
class EventTest < # Test::Unit::TestCase
  ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    RpEvent.create
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test "table exists" do
    assert RpEvent.first, "There is an event class and at least one record"
  end

  test "event is typeable" do
    evt = RpEvent.create typenum: 1
    assert_equal evt.typename, "Session"
    assert_equal evt.typenum, 1
    assert_equal evt.typesym, :session
  end

end
