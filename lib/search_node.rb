
=begin
This class implements a tree that searches for relevance-weighted items in order.
Each node in the tree has a weight, and a sorted list of other such nodes (its ASSOCIATES). 

The associates are an open-ended queue, where only those relevant to the search are present
at any one time, because they are generated in importance order and a queue of only the most important
ones is maintained.

Each associate is responsible for generating a list of MEMBERS, each of which has its own 
importance. The members also appear in order of importance. 

The current importance of an associate is the importance of its last generated member, and the importance
of a node is the maximum current importance of all its associates.
=end
class SearchNode
  
  attr_accessor :weight, :member, :entity, :max_val
  
  def initialize entity
    @entity = entity
    @member = nil
    @threshold = @max_val = 1
    initialize_associates
  end

  # Provide the most relevant member across all associates
  def member
    return @member if @member
    if la = lead_associate
      @max_val = la.max_val # All subsequent members are guaranteed to have an equal or lower value
      @member = la.consume_member
    end
  end
  
  # Bubble the member up the tree
  def consume_member
    m = member
    @member = nil
    m
  end
  
private 
  
  def lead_associate
    while true do
      if @associates.empty?
        return nil unless get_next_associate
      else
        # Force a member to bubble up, and thus the first associate's max value to be set accurately
        if @associates[0].member
          # When the lead associate drops below our minimum prospective value, there
          # may be an associate in the queue which comes in ahead of the lead.
          if @associates[0].max_val < @threshold
            get_next_associate
          else
            # Check the ordering of associates
            if @associates[1] && (@associates[1].max_val > @associates[0].max_val)
              # Need to start over after sorting b/c new lead may not have a member
              @associates.sort! { |a1, a2| a1.max_val <=> a2.max_val }
            else
              return @associates[0]
            end
          end
        else
          # Dispose of the associate and repeat
          @associates.shift
        end
      end
    end
  end

  def get_next_associate
    nil
  end

  # Setup the associates array based on the associated entity
  def initialize_associates
    @associates = []
    case @entity_type
      when "Tag"
      when "User"
      when "List"
      when "Feed"
      when "Site"
      when "Recipe"
    end
    if @associates[0]
      @threshold = @associates[0].max_val
    end
  end
end