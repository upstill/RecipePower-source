require 'fast_stemmer'

# A Lexaur is a node (or the root) in a syntax tree that stores strings.
# Each node in the tree has two attributes. Each is a hash on the first word
# in a string:
#   -- :terminals have one entry for each word where the word is the LAST word in the string.
#     The values in the hash are a collection of data, each element associated with the complete
#     string terminating with this word
#   -- :nexts has one entry for each word that continues the string which got us here.
#     Each value in the hash is a Lexaur object for the rest of the string
# "Parsing" a string begins at the root of the tree with the first word in the string, and recursively
# down the tree with the remainder of the string.

class Lexaur < Object
  attr_accessor :terminals, # Data stashed for the head word: an array of unique data values
                :nexts # Recurrence: hash on head word for subsequent strings

  # Build a tree of Lexaur objects, returning the root
  def initialize
    self.terminals = Hash.new
    self.nexts = Hash.new
  end

  # Build a Lexaur tree from the collection of tags in the database
  def self.from_tags
    lex = self.new
    Tag.all.each { |tag|
      puts "#{tag.typename}: (#{tag.id}) #{tag.name}"
      lex.take tag.name, tag.id
    }
    lex
  end

  # Process a string or an array of strings to find a place in the tree to store the data
  # The input may be a space-separated string which can be split into the array
  # Stemming may be suppressed by setting do_stem to false
  def take strings, data, do_stem=true
    strings = split strings, do_stem
    first = strings.shift
    if strings.empty? # We're done => store the data in my hash
      (terminals[first] ||= Array.new).push data unless terminals[first]&.include?(data)
    else
      (nexts[first] ||= Lexaur.new).take strings, data
    end
  end

  # Find the data for the sequence of strings
  # The input may be a space-separated string which can be split into the array
  # Stemming may be suppressed by setting do_stem to false
  def find strings, do_stem=true # Unsplit, unstemmed string is accepted
    strings = split strings
    strings = strings.map { |str| Stemmer::stem_word(str) } if do_stem
    return nil if strings.empty?
    first = strings.shift
    strings.empty? ? terminals[first] : nexts[first]&.find(strings)
  end

  # Our own #split function which (currently) separates out punctuation
  def split string_or_strings, do_stem=true
    strings = string_or_strings.is_a?(String) ? tokenize(string_or_strings) : string_or_strings
    do_stem ? strings.map { |str| Stemmer::stem_word(str) } : strings
  end

  # Drive a Lexaur using a stream. The stream only needs to implement three methods:
  # -- #peek provides the word at the head of the stream
  # -- #first peaks at the head but also advances the stream, consuming the first element
  #     for the remainder
  # -- #rest returns a stream for the stream minus the head.
  def chunk stream, do_stem=true, &block
    chunk1 stream, do_stem, block
  end

protected
  
  def chunk1 stream, do_stem, block
    # If there's a :nexts entry on the head of the stream, we try chunking the remainder,
    if (head = stream.peek) && head.is_a?(String) # More in the stream
      head = Stemmer::stem_word head if do_stem
      nexts[head]&.chunk1(stream.rest, do_stem, block) ||
          # ...otherwise, we consume the head of the stream
          (block.call(terminals[head], stream.rest) if terminals[head])
    end
  end
end
