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
  def init_search attenuation, weight
    @member = nil
    @associates = []
    @attenuation = attenuation # Attenuation is the compounded weights in descending to this associate
    @weight = weight
    @member, @value = nil, weight
  end

  # Get the next member of value t or greater, if any
  def member_of_at_least t, clear=true
    if @member && (@value >= t) # Member is already cached
      m = @member
      @member = nil if clear
      return m
    end
    acc_bar = (t <= weight) ? (t / weight) : 1.01 # The target value as seen by associates
    ensure_associates acc_bar, true
    while (first_assoc = @associates[0]) && (first_assoc.value >= acc_bar)
      # The first associate meets the threshold, which only means that it's worth
      # checking further: it may not have a current member, and generating the actual member
      # may reduce the associate's value, which may invalidate the sort order of the associates.
      pv = first_assoc.value # Save for comparison
      first_assoc.member_of_at_least acc_bar, false # Force the appearance of member
      if first_assoc.value == 0 # The foremost associate did NOT produce a member and CANNOT produce more
        @associates.shift
      # If the value of the first associate doesn't change--either b/c no member was generated or
      # the value of the new associate is the same as the old--then everything is secure
      elsif first_assoc.value < pv
        # If the value of the first associate HAS declined, the sort order may have changed
        ensure_associates first_assoc.value # Make sure we have all associates relevant to the new value
        # Adjust the sort order as nec.
        sort_first # Bubblesort because 1) the only thing that's changed is the leader, and 2) we're betting that the new place for the leader is near the front
      else
        break
      end
    end
    # Now we have a member IFF the first associate produced one of the stipulated value
    if first_assoc
      mem = first_assoc.member
      first_assoc.member = nil # Bubble the member up the tree
      @member, @value = (mem unless clear), (pv * @weight)
      mem
    end
  end

  protected

  def sort_first
    if @associates[0].value < @associates[1].value
      associate = @associates.shift
      np = 1
      while (np < @associates.count) && (associate.value < @associates[np].value)
          np += 1
      end
      @associates.insert np, associate
    end
  end

  def member= memval
    @member = memval
  end

end
