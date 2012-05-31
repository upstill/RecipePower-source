require 'test_helper'
require 'rails/performance_test_help'

class BrowsingTest < ActionDispatch::PerformanceTest
  # Refer to the documentation for all available options
  # self.profile_options = { :runs => 5, :metrics => [:wall_time, :memory]
  #                          :output => 'tmp/performance', :formats => [:flat] }

  def test_import
    get '/recipes/new?url=http%3A%2F%2Fwww.nytimes.com%2F2012%2F04%2F11%2Fdining%2Fpink-grapefruit-and-radicchio-salad-with-dates-recipe.html%3F_r%3D1%26partner%3Drss%26emc%3Drss&title=Pink%20Grapefruit%20and%20Radicchio%20Salad%20with%20Dates%20and%20Pistachios%20-%20Recipe%20-%20NYTimes.com&notes=&v=6&jump=yes'
  end
end
