require 'test_helper'
require './lib/array_utils'
class ArrayUtilsTest < ActiveSupport::TestCase

  def setup
    super
  end
  test "condense" do
    assert_equal [], condense_strings([])
    assert_equal %w{ a }, condense_strings(%w{ a })
    assert_equal %w{ a b c }, condense_strings(%w{ a b c })
    assert_equal %w{ a b c }, condense_strings(%w{ a b ba c })
    assert_equal %w{ a b c }, condense_strings(%w{ a b ba bad badder c })
    assert_equal %w{ a b c }, condense_strings(%w{ c badder b bad ba a })
  end
end

