# Recursively search the Enumerable obj for a key, returning a collection of values
def deep_collect(obj, key)
  # The base case for our recursive method. Returns if the key is found.
  found = []
  found << obj[key] if obj.respond_to?(:key?) && obj.key?(key)

  # If the object is either a Hash or Array

  found << obj.collect { |*a| deep_collect(a.last, key) } if obj.is_a? Enumerable
  found.flatten.compact
end

