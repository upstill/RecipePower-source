
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  # A new search node EITHER gets a global cutoff value (for a root node) OR a declared parent
  def initialize parent_or_cutoff=nil, weight=1.0
    if parent_or_cutoff.is_a? SearchTestNode
      parent_or_cutoff.init_child_search self, weight
    else
      init_search weight, parent_or_cutoff
    end
    self.search_result = search_node_value
    @cur_assoc_index = 9
  end

  # Method required of associates in the search tree to create the next associate
  # It will return nil if no more associates can be provided with a value greater than minval
  def new_child
    # The local weight of the node is a function of the class
    if @cur_assoc_index > 0
      weight = @cur_assoc_index/10.0
      @cur_assoc_index -= 1
      # We disallow any nodes whose global value would be less than the cutoff
      SearchTestNode.new(self, weight) if (weight*child_attenuation) >= sn_cutoff
    end
  end
end

require 'test_helper'
class SearchTest < ActiveSupport::TestCase

  def setup
    super
  end
  test "Initialized properly" do
    sn = SearchTestNode.new
    assert_equal 1.0, sn.search_node_weight
    assert_equal 1.0, sn.search_node_value
  end

  test "First search_node_value out" do
    sn = SearchTestNode.new
    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.search_node_value
  end
  
  test "Tree terminates properly" do
    sn = SearchTestNode.new 0.71
    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 1.0, sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.9, sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9), sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal 0.8, sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.9*0.9), sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.9*0.8), sn.search_node_value

    sn.first_member
    puts "------------------------------------#{sn}"
    assert_equal (0.8*0.9), sn.search_node_value

    mem = sn.first_member
    puts "------------------------------------#{sn}"
    assert_nil mem
  end
end
