# Do a binary search on an array, looking for the member of the array that bins 'target'
# i.e., the target must be "between" the beginning of the returned bin and the beginning of the next bin
def binsearch arr, target
  return if arr.blank?
  low = 0
  high = arr.count
  loop do
    choice = (low + high) / 2
    bin_lower = arr[choice]
    bin_lower = yield(bin_lower) if block_given?
    bin_upper = arr[choice + 1]
    bin_upper = yield(bin_upper) if bin_upper and block_given?
    if target >= bin_lower
      return choice if !bin_upper || (bin_upper > target)
      # puts "Rejected #{arr[choice]}->#{arr[choice+1]}: too low"
      low = choice + 1
    else
      # puts "Rejected #{arr[choice]}->#{arr[choice+1]}: too high"
      return nil if high == choice
      high = choice
    end
  end
end