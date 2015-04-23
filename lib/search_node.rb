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
=end
module SearchNode

  attr_reader :value, :member, :weight, :attenuation

  # A search node has a weight denoting its relative importance vis-a-vis its owner.
  # It gets a procedure for generating new associates, which takes the list of existing
  # associates and a value, promising that the returned list of associates will include all
  # entities of that weight or greater
  # The idea is that as we go down the tree, the value of subtrees diminishes, so that the "next item"
  # search may be terminated when the net importance drops below the value of a member thus
  # far found.
  def init_search attenuation=1, weight = 1, cutoff = 0
    @member = nil
    @associates = []
    # Attenuation is the compounded weights in descending to this associate (The global-to-local xform)
    # Weight is the weighting of THIS node. Thus, attenuation*weight is 1) the attenuation of any children,
    # and thus 2) the greatest value that any child can achieve
    @attenuation = attenuation
    @cutoff = cutoff
    @member, @value = nil, (@weight = weight)
  end

  # Get the next member of value t or greater, if any
  def first_member clear=true
    if @member # Member is already cached
      m = @member
      @member = nil if clear
      return m
    end
    while first_assoc = @associates[0] || next_associate
      # The first associate meets the threshold, which only means that it's worth
      # checking further: it may not have a current member, and generating the actual member
      # may reduce the associate's value, which may invalidate the sort order of the associates.
      pv = first_assoc.value # Save for comparison
      first_assoc.first_member false # Force the appearance of member but don't consume it
      case first_assoc.value
        when 0.0  # The foremost associate did NOT produce a member and CANNOT produce more
          @associates.shift # Dispose of it and carry on
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
      @member, @value = (mem unless clear), (first_assoc.value * @weight)
      mem
    else
      @value = 0.0
      @member = nil
    end
  end

  protected

  def next_associate
    local_to_global = @attenuation*@weight
    # We disallow any nodes whose global value would be less than the cutoff
    if  (local_to_global >= @cutoff) &&
        (newnode = new_child local_to_global, @cutoff)
      @associates.push newnode
      newnode
    end
  end

  def emplace_leader
    leader = @associates[newplace = 0]
    if (@associates.count == 1) || (leader.value < @associates[-1].value)
      # The leader belongs beyond the current end of the array. But where?
      while na = next_associate
        # Keep going until there are no more associates OR one appears that will be before the current leader
        break if leader.value >= na.value
      end
      newplace = @associates.count - (na ? 2 : 1)
    else # There's > 1 associate AND the leader's value is >= the last associate's value
      newplace = 0
      newplace += 1 while leader.value < @associates[newplace+1].value
    end
    if newplace != 0
      ass = @associates.shift
      @associates.insert newplace, ass
    end
  end

  def member= memval
    @member = memval
  end

end
