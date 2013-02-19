
# Class for a hash of recipe keys, for sorting as integers and applying search results
class Candihash < Hash
    # Initialize the candihash to a set of keys
    def initialize(startset) # , mode)
       startset.each { |rid| self[rid.to_s] = 0 }
       # @mode = mode
    end

    def reset keys
       self.clear
       keys.each { |key| self[key.to_s] = 0 }
    end

    # Apply a new set of keys to the existing set, either
    # by bumping the presence counts (:rcpquery_loose)
    # or by intersecting the sets (:rcpquery_strict)
    def apply(newset)
        # case @mode 
    	# when :rcpquery_strict
    	    # newset.select { |id| self[id.to_s] }
    	    # self.reset newset
    	# when :rcpquery_loose 
    	    newset.each { |id| self[id.to_s] += 1 if self[id.to_s] }
    	# end
    end

    # Return the keys as an integer array, sorted by number of hits
    # 'rankings' is an array of rid/ranking pairs, denoting the place of 
    # each recipe in some prior ordering. Use that ranking to constrain the output
    def results (rankings = nil)
    	# Extract the keys and sort them by success in matching
    	if rankings.blank?
      	return self.delete_if { |k, v| v == 0 }.sort { |k1, k2| self[k1] <=> self[k2] }.map { |k, v| k.to_i }
    	end
    	buffer1 = self.keys.select { |k| self[k] > 0 }.sort! { |k1, k2| self[k1] <=> self[k2] } 

    	# See if the prior rankings have anything to say about matters
    	buffer2 = rankings.keys.keep_if { |k| self[k] } # Only keep found keys
    	return buffer1.map { |k| k.to_i } if buffer2.empty?

    	# Apply rankings from prior queries
    	buffer2 = rankings.keys.sort { |k1, k2| self[k1] < 0 ? -1 : (self[k2] < 0 ? 1 : (self[k1] <=> self[k2])) }

    	# Now we have two buffers of key strings, ordered by desired output.
    	# We also have 'rankings', that states the desired slot for each key
    	# Keys in buffer2 go into their stated slot (or at the end)
    	result = []
    	# Process keys in order
    	until buffer1.empty? || buffer2.empty?
    	    if(rankings[buffer2.first] == result.size)
    	        result.push buffer2.shift
    	    else # Slot not occupied from rankings
    		id = buffer1.shift
    	        result.push id unless rankings[id] # ...but this id may have a later slot
    	    end
    	end
    	result << buffer1 unless buffer1.empty?
    	result << buffer2 unless buffer2.empty?
    	result.map { |r| r.to_i }
    end

end
