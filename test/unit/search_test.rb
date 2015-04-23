
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  def initialize attenuation=1, weight=1, cutoff=0
    # init_search is defined by the SearchNode module to initialize this node as a search associate
    init_search attenuation, weight, cutoff
    @sn_current_result = @sn_value
    @cur_assoc_index = 9
  end

  # Method required of associates in the search tree to create the next associate
  # It will return nil if no more associates can be provided with a sn_value greater than minval
  def new_child attenuation, minval
    # The local weight of the node is determined by the class
    weight = (@cur_assoc_index/10.0)
    # We disallow any nodes whose global sn_value would be less than the cutoff
    if  (@cur_assoc_index > 0) &&
        ((weight*attenuation) >= minval) &&
        (newnode = SearchTestNode.new attenuation, weight, minval)
      @cur_assoc_index -= 1
      newnode
    end
  end
end

require 'test_helper'
class SearchTest < ActiveSupport::TestCase
  test "Initialized properly" do
    sn = SearchTestNode.new
    assert_equal 1.0, sn.sn_assoc_weight
    assert_equal 1.0, sn.sn_value
  end

  test "First sn_value out" do
    sn = SearchTestNode.new
    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.sn_value
  end
  
  test "Tree terminates properly" do
    sn = SearchTestNode.new 1.0, 1.0, 0.71
    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.sn_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.8*0.9), sn.sn_value

    mem = sn.first_member
    puts "------------------------------------#{sn}"
    assert_nil mem
  end
end
