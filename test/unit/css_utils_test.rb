require 'test_helper'
class CssUtilsTest < ActiveSupport::TestCase
require './lib/css_utils.rb'

  test "products work" do
    assert_equal "2.4em", dim_scale("1.2em", 2)
    assert_equal "2.4em", dim_scale("1.2em", 2.0)
    assert_nil dim_scale("100%", 2.0)
    assert_nil dim_scale("auto", 2.0)
    assert_equal "2.4", dim_scale("1.2", 2)
    assert_equal "2.4", dim_scale("1.2", 2.0)
    assert_equal "2", dim_scale("1", 2)
    assert_equal "2", dim_scale("1", 2.0)
    assert_equal "2", dim_scale(1, 2)
    assert_equal "2", dim_scale(1, 2.0)
  end
end