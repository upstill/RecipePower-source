# encoding: UTF-8
# require 'test_helper'
ENV["RAILS_ENV"] = "test"
require File.expand_path('../../../config/environment', __FILE__)
require 'rails/test_help'
gem 'minitest'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  # fixtures :all

  # Add more helper methods to be used by all tests here...
end

load 'lib/rcp_browser.rb'

class RcpBrowserTest < ActiveSupport::TestCase 
  test "browser initialized correctly" do
      rb = RcpBrowser.new 3
      assert_equal rb.handle, "", "Handle at top of browser not blank: '#{rb.handle}'"
  end
  
  test "basic browser dumped and loaded" do
     rb = RcpBrowser.new 3
     dump1 = rb.dump
     puts "Dump of Original: "+dump1
     rb2 = RcpBrowser.load dump1
     dump2 = rb2.dump
     puts "Dump of Copy: "+dump2
     assert_equal dump1, dump2, "Restored version not same as first"
  end
  
  test "browser with tag tokens dumped and loaded" do
     rb = RcpBrowser.new({ :userid=>3, :tag_tokens=>[125, "something weird"] })
     dump1 = rb.dump
     puts "Dump of Original: "+dump1
     rb2 = RcpBrowser.load dump1
     dump2 = rb2.dump
     puts "Dump of Copy: "+dump2
     assert_equal dump1, dump2, "Restored version not same as first"
  end
end