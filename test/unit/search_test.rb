
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  def initialize attenuation=1, weight=1, cutoff = 0.0
    init_search attenuation, weight
    @member = @value
    @cur_assoc_index = 9
    # Don't produce any associates that will produce any values < cutoff
    @cutoff = cutoff
  end

  def next_associate
    local_to_global = @attenuation*@weight
    local_val = (@cur_assoc_index/10.0)
    # We disallow any nodes whose global value would be less than the cutoff
    if (@cur_assoc_index > 0) && (local_val*local_to_global >= @cutoff)
      newnode = SearchTestNode.new local_to_global, local_val, @cutoff
      @associates.push newnode
      @cur_assoc_index -= 1
      newnode
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
    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.value
  end
  
  test "Tree terminates properly" do
    sn = SearchTestNode.new 1, 1, 0.71
    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.8*0.9), sn.value

    mem = sn.first_member
    puts "------------------------------------#{sn}"
    assert_nil mem
  end
end
