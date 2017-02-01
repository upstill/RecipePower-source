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

  test "subpaths" do
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a', 'www.ganga.com/a/index.html'], subpaths('http://www.ganga.com/a/index.html')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('http://www.ganga.com/a')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/?')
    assert_equal [ 'www.ganga.com' ], subpaths('https://www.ganga.com')
    assert_equal [ 'www.ganga.com' ], subpaths('http://www.ganga.com/')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/?d=12/')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/#{?}')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/#{?}d=12/')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/?a=1#{?}')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/?a=1#{?}d=12/')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('http://www.ganga.com/a')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a' ], subpaths('https://www.ganga.com/a/')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a', 'www.ganga.com/a/b' ], subpaths('ftp://www.ganga.com/a/b')
    assert_equal [ 'www.ganga.com', 'www.ganga.com/a', 'www.ganga.com/a/b' ], subpaths('ftp://www.ganga.com/a/b/')
  end

  test "cleanpath" do
    assert_equal 'www.ganga.com/a/index.html', cleanpath('http://www.ganga.com/a/index.html')
    assert_equal 'www.ganga.com/a', cleanpath('http://www.ganga.com/a')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/?')
    assert_equal 'www.ganga.com', cleanpath('https://www.ganga.com')
    assert_equal 'www.ganga.com', cleanpath('http://www.ganga.com/')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/?d=12/')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/#{?}')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/#{?}d=12/')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/?a=1#{?}')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/?a=1#{?}d=12/')
    assert_equal 'www.ganga.com/a', cleanpath('http://www.ganga.com/a')
    assert_equal 'www.ganga.com/a', cleanpath('https://www.ganga.com/a/')
    assert_equal 'www.ganga.com/a/b', cleanpath('ftp://www.ganga.com/a/b')
    assert_equal 'www.ganga.com/a/b', cleanpath('ftp://www.ganga.com/a/b/')
  end
end

