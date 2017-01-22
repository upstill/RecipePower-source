# require 'test_helper'
# require 'rails/performance_test_help'

class RcpqueriesTest < ActionDispatch::PerformanceTest
  # Refer to the documentation for all available options
  # self.profile_options = { :runs => 5, :metrics => [:wall_time, :memory]
  #                          :output => 'tmp/performance', :formats => [:flat] }

  def test_max
    get '/rcpqueries?owner=1'
  end

  def test_aaron
    get '/rcpqueries?owner=2'
  end

  def test_steve
    get '/rcpqueries?owner=3'
  end

  def test_super
    get '/rcpqueries?owner=5'
  end

  def test_guest
    get '/rcpqueries?owner=4'
  end
  
  def test_relist
      get 'rcpqueries/146/relist'
  end
  
end
