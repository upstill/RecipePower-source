# A LexResult maintains the state of parsing out a single tag
class LexResult < Object
  attr_reader :furthest_stream, :str_path

  def initialize stream
    @furthest_stream, @longest_path, @str_path = (@initial_stream = stream), [], []
  end

  # Propose a match, recording it if it exceeds the length of the longest previously match
  def propose onwrd, lexpth, strpth
    @furthest_stream, @longest_path, @str_path = onwrd, lexpth, strpth if lexpth.length > @longest_path.length
  end

  # Report the current longest-path result by calling a block
  def report
    yield @longest_path.last.terminals[@str_path.last], @initial_stream, @furthest_stream if @longest_path.present?
  end

  # Use a trailing substring from the sequel to extend our path, if possible
  def extend sequel
    sequel.str_path.each_index do |ix|
      # Can we use the end sequence of strings to extend our path?
      prev = @longest_path.last
      path_extension = []
      string_extension = sequel.str_path[ix..-1] # Proposed string extension
      string_extension.each { |newstr|
        break unless prev = prev.nexts[newstr]
        path_extension.push prev
      }
      next unless string_extension.present?
      terms = (path_extension.last || @longest_path.last).terminals[string_extension.last]
      if path_extension.length == (string_extension.length-1) && terms
        propose @furthest_stream, @longest_path+path_extension, @str_path+string_extension
        return
      end
    end
  end
end

