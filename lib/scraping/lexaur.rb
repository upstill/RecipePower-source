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
  def self.from_tags *types
    lex = self.new
    puts "Creating Lexaur from tags of type(s) '" + types.join("', '") + '\'.'
    Tag.of_type(types).each { |tag|
      puts "#{tag.typename}: (#{tag.id}) #{tag.name}"
      lex.take tag.name, tag.id
    }
    lex
  end

  # Process a string or an array of strings to find a place in the tree to store the data
  # The input may be a space-separated string which can be split into the array
  def take strings, data
    strings = split strings
    first = strings.shift
    if strings.empty? # We're done => store the data in my hash
      (terminals[first] ||= Array.new).push data unless terminals[first]&.include?(data)
    else
      (nexts[first] ||= Lexaur.new).take strings, data
    end
  end

  # Find the data for the sequence of strings
  # The input may be a space-separated string which can be split into the array
  def find string_or_strings # Unsplit, unstemmed string is accepted
    strings = split string_or_strings
    strings = strings.map { |str| Tag.normalizeName(str).split('-') }.flatten
    return nil if strings.empty?
    first = strings.shift
    strings.empty? ? terminals[first] : nexts[first]&.find(strings)
  end

  # Drive a Lexaur using a stream. The stream only needs to implement three methods:
  # -- #peek provides the word at the head of the stream
  # -- #first peaks at the head but also advances the stream, consuming the first element
  #     for the remainder
  # -- #rest returns a stream for the stream minus the head.
  def chunk stream, &block
    chunk1 stream, block
  end

protected

  # Our own #split function which (currently) separates out punctuation
  def split string_or_strings
    strings = string_or_strings.is_a?(String) ? tokenize(string_or_strings) : string_or_strings
    strings.map { |str| Tag.normalizeName(str).split('-') }.flatten
  end

  def chunk1 stream, block
    # If there's a :nexts entry on the token of the stream, we try chunking the remainder,
    if (token = stream.peek).present? && token.is_a?(String) # More in the stream
      substrs = Tag.normalizeName(token).split '-'
      tracker = self
      head = substrs.pop || '' # Save the last substring
      # Descend the tree for each substring, depending on there being a head marker at each step along the way
      substrs.each do |substr|
        tracker = tracker.nexts[substr]
        return if tracker.nil?
      end
      # Peek ahead and consume any tokens which are empty in the normalized name
      onward = stream.rest
      onward = onward.rest if onward.peek == '.'
      tracker.nexts[head]&.chunk1(onward, block) ||
          # ...otherwise, we consume the head of the stream
          if terms = tracker.terminals[head]
            block.call terms, onward
          end
    end
  end
end
