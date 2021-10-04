require 'test_helper'
# require './lib/array_utils'
class BinCountTest < ActiveSupport::TestCase
  test 'bin_count' do
    a = { a: 1 }
    b = { b: 2 }
    bc = BinCount.new
    bc.increment a, b
    b[:b] = 3
    bc.increment b
    assert_equal 2, bc[b]
    assert_equal b, bc.sorted.first[0]
    bc[a] += 1000
    assert_equal 1001, bc[a]
    assert_equal a, bc.sorted.first[0]
    max = bc.max
    assert_equal 1001, max.count
  end
end