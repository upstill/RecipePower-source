require 'test_helper'
# require './lib/array_utils'
class AliasTest < ActiveSupport::TestCase

  def setup
    super
  end

  test "urleq" do
    assert Alias.urleq( 'something.com/', 'something.com' )
    assert Alias.urleq( 'something.com/else', 'something.com/else/' )
    assert Alias.urleq( 'something.com/else#doesntmatter', 'something.com/else/#alsodoesntmatter' )
    assert Alias.urleq( 'http://something.com/', 'something.com' )
    assert Alias.urleq( 'https://something.com/else', 'something.com/else/' )
    assert Alias.urleq( 'http://something.com/else#doesntmatter', 'something.com/else/#alsodoesntmatter' )
  end

  test "correct conversion of URLs for indexing" do
    # With protocol
    assert_equal 'something.com', Alias.indexing_url('http://something.com/#tgt')
    assert_equal 'something.com/something_else', Alias.indexing_url('http://something.com/something_else#tgt')
    assert_equal 'something.com/something_else?qieru', Alias.indexing_url('http://something.com/something_else/?qieru#tgt')
    assert_equal 'something.com/something_else?qieru', Alias.indexing_url('http://something.com/something_else?qieru#tgt')

    # Without protocol
    assert_equal 'something.com', Alias.indexing_url('something.com/#tgt')
    assert_equal 'something.com/something_else', Alias.indexing_url('something.com/something_else#tgt')
    assert_equal 'something.com/something_else?qieru', Alias.indexing_url('something.com/something_else/?qieru#tgt')
    assert_equal 'something.com/something_else?qieru', Alias.indexing_url('something.com/something_else?qieru#tgt')

    assert_equal 'http.google.com', Alias.indexing_url('http.google.com/#tgt')
  end

end
