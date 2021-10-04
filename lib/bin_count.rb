# Simple class to count instances of...well, of anything that has an object_id
class BCCount
  attr_reader :object, :count
  def initialize pair
    @object, @count = pair
  end

end

class BinCount < Hash

  def [] a
    super(a.object_id)&.last || 0
  end

  def []= a, ct
    super a.object_id, [a, ct]
    puts "#{a} set to #{self[a]}"
  end

  # Post one or more objects by incrementing their count (or initializing it to 1)
  def increment *objs
    objs.each { |obj| self[obj] += 1 }
  end

  # Present the results in sort order, biggest count first.
  # Return an array of object/count pairs
  # If a block is given, call the block on each pair
  def sorted
    st = values.sort_by(&:last).reverse
    st.each { |pair| yield *pair } if block_given?
    st
  end

  def max
    BCCount.new values.max_by(&:last) if self.present?
  end

  def delete obj
    super obj.object_id
  end

end
