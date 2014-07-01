require 'test/unit'
require 'test_helper'
class ListTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  test "create a list"  do
    tst = List.new
  end

  # Fake test
  def test_fail

    fail('Not implemented')
  end
end