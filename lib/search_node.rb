=begin
This class implements a tree that searches for relevance-weighted items in order.
Each node in the tree has a weight, and a sorted list of other such nodes (its ASSOCIATES). 

The associates are an open-ended queue, where only those relevant to the search are present
at any one time, because they are generated in value order and a queue of only the most important
ones is maintained, where "important" means "able to meet a threshold". The threshold
that no non-resident associate will exceed is @threshold.

Each associate is responsible for generating a list of MEMBERS, each of which has its own 
value. The members also appear in order of value.

The current value of an associate is the value of its last generated member, adjusted by the
associate's weight.

External interface:

  new_child is a method that including classes may define to create new associates

  init_search cutoff = nil, weight=1.0   # Initialize an associate
  init_child_search child, weight # Hook a child into a parent
  first_member clear=true # Get the next result from the (sub)tree, destructively if clear is true
  child_attenuation # The prospective attenuation that will be assigned to any children (before their weight)
  set_children associates # Set the children of the node via array (which will get sorted)
  sort_children # Make sure the children are sorted, e.g. after inserting a number of them.

=end
module SearchNode

  attr_accessor :search_result
  attr_reader :search_node_value, :search_node_weight, :sn_local_to_global, :sn_cutoff

  # A search node (an associate) has a weight denoting its relative importance vis-a-vis its owner.
  # Each associate has a value representing either
  # 1) the value of the pending result (MEMBER), or
  # 2) the maximum value of any subsequent members.
  # Associate values are used to sort the associates. Thus, members may be provided in descending order of
  # their value.
  # Each associate also has a weight for the significance of its results compared to its parents. The weights
  # going down the tree are accumulated into the sn_local_to_global value, which gives any value a global
  # significance, thus the "next item" search may be terminated when the net importance of an associate
  # drops below the value of a member thus far found.

  # Initialize a search associate of a specific weight. There is no local-to-global scale factor at this
  # juncture; if adding nodes to the tree, the parent uses its init_child_search method
  def init_search cutoff = nil, weight=1.0
    @search_result = nil
    @sn_associates = []
    # Attenuation is the compounded weights in descending to this associate (The global-to-local xform)
    # Weight is the weighting of THIS node. Thus, attenuation*weight is 1) the attenuation of any children,
    # and thus 2) the greatest value that any child can achieve
    @sn_cutoff = cutoff || 0.0
    @sn_local_to_global = 1.0
    @search_result = nil
    @search_node_value = (@search_node_weight = weight)
  end

  def init_child_search child, weight = 1.0
    child.init_search @sn_cutoff, weight
    # The attenuation for a child is the attenuation of the parent times the weight of the parent
    child.sn_local_to_global = child_attenuation
    @sn_associates.push child
  end

  # Get the next result from the tree, if any
  def first_member clear=true
    if @search_result # Member is already cached
      m = @search_result
      @search_result = nil if clear
      return m
    end
    while first_assoc = @sn_associates[0] || push_new_associate
      # The first associate meets the threshold, which only means that it's worth
      # checking further: it may not have a current member, and generating the actual member
      # may reduce the associate's value, which may invalidate the sort order of the associates.
      pv = first_assoc.search_node_value # Save for comparison
      first_assoc.first_member false # Force the appearance of member but don't consume it
      case first_assoc.search_node_value
        when 0.0  # The foremost associate did NOT produce a member and CANNOT produce more
          @sn_associates.shift # Dispose of it and carry on
        when pv
          # If the value of the first associate doesn't change--either b/c no member was generated or
          # the value of the new associate is the same as the old--then everything is secure
          break
        else
          # If the value of the first associate HAS declined as a result of getting its next member
          # (it should NEVER increase), then sort order of associates may need to change.
          # We may even need to bring in more associates to find a place for the current leader.
          emplace_leader
      end
      # Loop back to check up on the new leader
    end
    # Now we have a member IFF the first associate produced one of the stipulated value
    if first_assoc
      mem = first_assoc.first_member # Bubble the member up the tree
      @search_result, @search_node_value = (mem unless clear), (first_assoc.search_node_value * @search_node_weight)
      mem
    else
      @search_node_value = 0.0
      @search_result = nil
    end
  end

  def to_s level=0
    indent = "\n"+('   '*level)
    "#{indent}Attenuation: #{@sn_local_to_global}#{indent}Weight: #{@search_node_weight}#{indent}Value: #{@search_node_value}#{indent}Member:#{@search_result}"+@sn_associates.collect{ |as| as.to_s level+1}.join
  end

  # The attenuation at a child is the product of this node's attenuation and its weight
  def child_attenuation
    @child_attenuation ||= @sn_local_to_global*@search_node_weight
  end

  def set_children child_associates=[]
    @sn_associates = child_associates.sort { |a1, a2| a1.search_node_value <=> a2.search_node_value }
  end

  # new_child is a hook that allows an associate to dynamically add child associates on demand
  def new_child
    nil
  end

  protected

  attr_writer :search_node_weight, :search_node_value, :sn_local_to_global

  # push_new_associate uses the new_child method to push a new associate onto the queue
  def push_new_associate
    # We short-circuit any nodes whose global value would be less than the cutoff
    new_child unless child_attenuation < @sn_cutoff
  end

  def emplace_leader
    leader = @sn_associates[newplace = 0]
    if (@sn_associates.count == 1) || (leader.search_node_value < @sn_associates[-1].search_node_value)
      # The leader belongs beyond the current end of the array. But where?
      while na = push_new_associate
        # Keep going until there are no more associates OR one appears that will be before the current leader
        break if leader.search_node_value >= na.search_node_value
      end
      newplace = @sn_associates.count - (na ? 2 : 1)
    else # There's > 1 associate AND the leader's value is >= the last associate's value
      newplace = 0
      newplace += 1 while leader.search_node_value < @sn_associates[newplace+1].search_node_value
    end
    if newplace != 0
      ass = @sn_associates.shift
      @sn_associates.insert newplace, ass
    end
  end

  def search_result= memval
    @search_result = memval
  end

end

# A SearchAggregator is a special SearchNode that collects the results of
# another set of search nodes and presents the top N results
class SearchAggregator
  include SearchNode

  def initialize *associates
    super
    @sn_associates = associates
    @result_counts = {}
    @results_cache = []
  end

  def next_members n=10
    first = @results_cache.count
    while m = first_member
      stopval ||= search_node_value/20
      @result_counts[m] = (@result_counts[m] || 0.0) + search_node_value
      # Terminate at the tail
      break if search_node_value < stopval
    end
    @results_cache << (@result_counts.sort_by {|_key, value| value}.reverse.map(&:first) - @results_cache)[0...n]
    @results_cache[first...(first+n)]
  end
end
