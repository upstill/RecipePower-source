
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  def initialize attenuation=1, weight=1
    @@tree ||= self
    init_search attenuation, weight
    @member = @value
    @more_associates = 9
  end

  def ensure_associates satisfaction_value, minimal = false
    cv = @associates.present? ? @associates[-1].value : 1.0
    while (cv > satisfaction_value) && (@more_associates > 0)
      @associates.push (na = SearchTestNode.new(@attenuation*@weight, (@more_associates*0.1)))
      @more_associates -= 1
      break if ((cv = na.value)>satisfaction_value) && minimal
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
    sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.value

    sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.value

    sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.value

    sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.value

    sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.value

    sn.member_of_at_least(0)
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.value
  end
end
