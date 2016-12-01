# Reduce the array to eliminate strings that are just extensions
# [] -> []
# [ 'a' ] -> [ 'a' ]
# [ 'a', 'b', 'b', 'c' ] -> [ 'a' 'b' 'c' ]
# [ 'a', 'b', 'ba', 'c' ] -> [ 'a' 'b' 'c' ]
# [ 'a', 'b', 'ba', 'bad', 'badder', 'c' ] -> [ 'a' 'b' 'c' ]
def condense_strings arr
  arr.sort!
  arr.keep_if.with_index { |v,i|
    (i == 0) || !v.start_with?(arr[i-1])
  }
end
