
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  def initialize attenuation=1, weight=1
    init_search attenuation, weight
    @member = @value
  end

  def ensure_associates threshold_value, minimal = false
    cv, cw = @associates.present? ?
        [@associates[-1].value, @associates[-1].weight] :
        [1.0, 0.9]
    while cv > threshold_value
      @associates.push (na = SearchTestNode.new(@attenuation*@weight, cw))
      break if ((cv = na.value)>threshold_value) && minimal
      cw = cw - 0.1
    end
  end

  def to_s level=0
    indent = "\n"+('   '*level)
    "#{indent}Attenuation: #{@attenuation}#{indent}Weight: #{@weight}#{indent}Value: #{@value}#{indent}Member:#{@member}"+@associates.collect{ |as| as.to_s level+1}.join
  end
end

require 'test_helper'
class SearchTest < ActiveSupport::TestCase
  test "Initialized properly" do
    sn = SearchTestNode.new
    assert_equal 1.0, sn.weight
    assert_equal 1.0, sn.value
  end

  test "First value out" do
    sn = SearchTestNode.new
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.member_of_at_least(0)

    expected = sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal 0.9, expected

    expected = sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), expected
  end
end
