
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  def initialize attenuation=1, weight=1, cutoff=0
    # init_search is defined by the SearchNode module to initialize this node as a search associate
    init_search attenuation, weight, cutoff
    @member = @value
    @cur_assoc_index = 9
  end

  # Method required of associates in the search tree to create the next associate
  # It will return nil if no more associates can be provided with a value greater than minval
  def new_child attenuation, minval
    # The local weight of the node is determined by the class
    weight = (@cur_assoc_index/10.0)
    # We disallow any nodes whose global value would be less than the cutoff
    if  (@cur_assoc_index > 0) &&
        ((weight*attenuation) >= minval) &&
        (newnode = SearchTestNode.new attenuation, weight, minval)
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
