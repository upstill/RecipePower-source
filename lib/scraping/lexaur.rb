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
      puts "#{tag.typename}: (#{tag.id}) #{tag.name}" if Rails.env.test?
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
  def chunk stream, skipper: -> (stream){ stream }, &block
    chunk1 stream, -> (terms, onward, lexpath) { block.call terms, onward }, skipper: skipper
  end

  # Match a list of tags of the form 'tag1, tag2...and/or tag3'
  def match_list stream, skipper: -> (stream){ stream }, &block
    lexpath = onward = terms = nil
    chunked = chunk1 stream, -> (trms, onwrd, lexpth) {
      lexpath = lexpth
      block.call (terms = trms), (onward = onwrd)
    }, skipper: skipper
    if chunked
      lexpath = lexpath.reverse
      # chunk_path provides a path through the tree to the terminals
      while %w{ , and or }.include? (delim = onward.peek) do
        onward = onward.rest
        lexpath.each do |lexnode|
          lexnode.chunk(onward) { |terms, newstream|
            onward = newstream if block.call terms, newstream # Report found tokens back
          }
        end
        return onward if delim != ',' # Termination condition: hitting 'and' or 'or'
      end
    end
  end

protected

  # Our own #split function which (currently) separates out punctuation
  def split string_or_strings
    strings = string_or_strings.is_a?(String) ? tokenize(string_or_strings) : string_or_strings
    strings.map { |str| Tag.normalizeName(str).split('-') }.flatten
  end

  def chunk1 stream, lexpath = [], block, skipper: -> (stream) { stream }
    lexpath, block = [], lexpath if lexpath.is_a?(Proc)
    lexpath = lexpath + [self]
    # If there's a :nexts entry on the token of the stream, we try chunking the remainder,
    while stream.more? && (stream.peek == "\n") do
      stream = stream.rest
    end
    if (token = stream.peek).present? && token.is_a?(String) # More in the stream
      substrs = Tag.normalizeName(token).split '-'
      tracker = self
      if substrs.present?
        head = substrs.pop || '' # Save the last substring
        # Descend the tree for each substring, depending on there being a head marker at each step along the way
        substrs.each do |substr|
          tracker = tracker.nexts[substr]
          return if tracker.nil?
        end
        # Peek ahead and consume any tokens which are empty in the normalized name
        onward, unskipped = elide(stream.rest, skipper)
        tracker.nexts[head]&.chunk1(onward, lexpath, block, skipper: skipper) ||
            # ...otherwise, we consume the head of the stream
            if terms = tracker.terminals[head]
              block.call terms, unskipped, lexpath # The block must check for acceptance and return true for the process to end
            end
      else # This token didn't match to anything in Tag.normalizeName
        head = ''
        unskipped = onward = stream.rest
        tracker.chunk1(onward, lexpath, block, skipper: skipper)
      end
    end
  end

  private

  # Take an opportunity to pass up unwanted/irrelevant tokens
  def elide stream, skipper
    unskipped = stream
    stream = skipper.call stream
    case stream.peek
    when '.' # Ignore period
      unskipped = stream = stream.rest
    when '(' # Elide parenthetical by hunting for matching ')'
      to_match = stream.rest
      while to_match && (to_match.peek != ')') do
        to_match = to_match.rest
      end
      stream = to_match.rest if to_match
    end
    [stream, unskipped]
  end
end
