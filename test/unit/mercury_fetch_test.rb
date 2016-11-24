require 'test_helper'
require 'mercury_data.rb'
class MercuryFetchTest < ActiveSupport::TestCase
  test 'fetches sample' do
    mf = MercuryData.new 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/'
    assert_not_nil mf
    assert_equal 'https://www.wired.com/2016/09/ode-rosetta-spacecraft-going-die-comet/', mf.url
  end
end