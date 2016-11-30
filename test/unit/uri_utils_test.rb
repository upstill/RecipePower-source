require 'test_helper'
require './lib/uri_utils'
class UriUtilsTest < ActiveSupport::TestCase

  test "all" do
    assert_equal [], normalize_urls([])
    assert_equal ['http://ganga.com/'], normalize_urls('http://ganga.com')
    assert_equal ['ganga.com/'], normalize_urls('http://ganga.com', true)
    assert_equal ['http://ganga.com/', 'http://ganja.com/'], normalize_urls(['http://ganga.com', 'http://ganja.com/'])
    assert_equal ['ganga.com/', 'ganja.com/'], normalize_urls(['http://ganga.com', 'http://ganja.com/'], true)
    assert_equal [], normalize_urls('bogus url')
  end
end

