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
    return unless @longest_path.present? && (pe_start = @longest_path[@str_path.length-1].nexts[@str_path.last])
    sequel.str_path.each_index do |ix|
      # Can we use the end sequence of strings to extend our path?
      path_extension = [ appendix = pe_start ]
      string_extension = sequel.str_path[ix..-2] # Proposed string extension
      while next_str = string_extension.shift do
        break unless appendix = appendix.nexts[next_str]
        path_extension.push appendix
      end
      if string_extension.empty? && appendix && # All prior strings have been mapped
          appendix.terminals[sequel.str_path.last]  # ...and the last string has terminal data
        propose @furthest_stream, @longest_path+path_extension, @str_path+sequel.str_path[ix..-1]
        return
      end
    end
  end
end

