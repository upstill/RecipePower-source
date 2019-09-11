require 'test_helper'
require 'scraping/scanner.rb'

class ScannerTest < ActiveSupport::TestCase
  test 'basic stream operations' do
    scanner = StrScanner.new 'Fourscore and seven years ago'
    assert_equal 'Fourscore', scanner.first
    assert_equal 'and seven', scanner.peek(2)
    assert_equal 'and seven', scanner.first(2)
  end
end