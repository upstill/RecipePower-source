require 'test_helper'
class StringUtilsTest < ActiveSupport::TestCase

  def setup
    super
  end

  test "struct to string" do
    puts struct_to_str( { :a => 'a' } )
    h =  {:a=>{:d=>"d"}, :b=>"c"}
    puts struct_to_str(h)
  end

  test 'deflate' do
    before = " a\t   \u00a0\u00a0\u00a0b      c    "
    after = " a\u00a0b c "
    assert_equal after, before.deflate
    assert_equal " a b c", " a b c".deflate
    assert_equal "abc", "abc".deflate
    assert_equal " a b c ", " a\t         b c    ".deflate
    assert_equal " a\nb c ", " a\t   \nb      c    ".deflate
    assert_equal "\n", "\n\n\n\n".deflate
    assert_equal "\n", "\n \n".deflate
  end
end
