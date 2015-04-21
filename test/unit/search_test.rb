
# This class tests the search module. When repeatedly called, it produces
# a continuously-diminishing series of float calls
require './lib/search_node.rb'
class SearchTestNode
  include SearchNode

  def initialize attenuation=1
    init_search attenuation
    @member = @value
  end

  def ensure_associates value
    cv, cw = @associates.present? ?
        [@associates[-1].value, @associates[-1].weight] :
        [1.0, 0.9]
    while cv > value
      @associates.push (na = SearchTestNode.new(cw))
      cv = na.value
      cw = cw - 0.1
    end
  end

  def to_s level=0
    "#{'\t'*level}Weight: #{@weight}\nValue: #{@value}\n"+@associates.collect{ |as| as.to_s level+1}.join('\n')
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
    puts sn
    assert_equal 1.0, sn.member_of_at_least(0)
    assert_equal 0.9, sn.member_of_at_least(0)
  end
end
