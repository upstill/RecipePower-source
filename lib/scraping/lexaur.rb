require 'fast_stemmer'
require 'scraping/lex_result.rb'

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
    @terminals = Hash.new
    @nexts = Hash.new
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
    chunk1 stream, -> (terms, onward, lexpath, strpath) {
      block.call terms, onward if block_given? && terms.present?
    }, skipper: skipper
  end

  # Distribute subterms about a delimiter token
  def distribute stream, skipper: -> (stream){ stream }, lexpath: [self], strpath: [], result: LexResult.new(stream), reporter: nil, &block
    reporter ||= block
    onward = terms = nil
    # Find at least one path down the tree driven by the incoming tokens.
    # #chunk1 invokes this block once each time a sequence hits, longest first
    # furthest_terms, furthest_stream, longest_path = [], stream, []
    while lex = lexpath.pop do
      lex.chunk1 stream, -> (trms, onwrd, lexpth, strpth) {
        # A completed path has been found => check for delimiter, and offer the path to subsequent tokens
        # terms: the data found at the terminus of the search
        # stream: the stream as consumed in proceeding down the tree
        # newpath: the lexaur path from the root to the matched data
        # We want the longest path and the furthest stream that produces a term
        result.propose trms, onwrd, lexpth, strpth
        if %w{ , and or }.include? (delim = onwrd.peek)
          # subsq_terms, subsq_stream, subsq_path = [], onwrd = onwrd.rest, []
          # ...and we might be able to extend the current longest_path with tokens from the subsequent result
          result.extend lex.distribute(onwrd = onwrd.rest,
                          skipper: skipper,
                          lexpath: lexpath+lexpth,
                          strpath: strpath+strpth,
                          reporter: reporter)
        end
      }, skipper: skipper
    end
    result.report reporter
    return result
    onward = onward.rest
    if chunked
      # We have a successful match => search for the longest stream that can be
      # gleaned using an initial subpath of lexnode
      lexpath.each do |lexnode|
        lexnode.chunk(onward) { |terms, newstream|
          onward = newstream if block.call terms, newstream # Report found tokens back
        }
      end
      # lexpath = lexpath.reverse
      # chunk_path provides a path through the tree to the terminals
      while %w{ , and or }.include? (delim = onward.peek) do
        lexpath.each do |lexnode|
          lexnode.chunk(onward) { |terms, newstream|
            onward = newstream if block.call terms, newstream # Report found tokens back
          }
        end
        return onward if onward.peek != ',' # Terminate if began with hitting 'and' or 'or'
        onward = onward.rest
      end
    end
  end

  # Match a list of tags of the form 'tag1, tag2...and/or tag3'
  def match_list stream, skipper: -> (stream){ stream }, &block
    lexpath = onward = terms = nil
    chunked = chunk1 stream, -> (trms, onwrd, lexpth) {
      lexpath = lexpth
      block.call (terms = trms), (onward = onwrd) if trms.present? # We call back up when one is found
    }, skipper: skipper
    if chunked
      # lexpath = lexpath.reverse
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

  # Consume tokens from the stream and walk down the Lexaur tree.
  # Call the supplied block for each matched sequence, longest first.
  # Newlines are ignored, as are sequences elided by the skipper proc
  def chunk1 stream, lexpath = [], strpath = [], block, skipper: -> (stream) { stream }
    lexpath, strpath, block = [], [], lexpath if lexpath.is_a?(Proc)
    lexpath = lexpath + [self]
    while stream.more? && (stream.peek == "\n") do
      stream = stream.rest
    end
    if (token = stream.peek).present? && token.is_a?(String) # More in the stream
      # The tree breaks any given token into the substrings found in the normalized name
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
        # Recursively continue along the stream and down the tree
        if nxt = tracker.nexts[head]
          nxt.chunk1(onward, lexpath, strpath + [head], block, skipper: skipper) ||
              # Once there are no more matches along/down, we consume the head of the stream.
              # NB This has the effect of returning the longest match first
              # Report back the terminals even if absent
              if terms = tracker.terminals[head]
                block.call(tracker.terminals[head], onward, lexpath, strpath + [head]) # The block must check for acceptance and return true for the process to end
              end
        elsif terms = tracker.terminals[head]
          block.call(tracker.terminals[head], onward, lexpath, strpath + [head]) # The block must check for acceptance and return true for the process to end
        else
          block.call(nil, elide(stream, skipper).first, lexpath, strpath) # The block must check for acceptance and return true for the process to end
        end
      else # This token didn't bear anything of relevance to Tag.normalizeName
        head = ''
        unskipped = onward = stream.rest
        tracker.chunk1 onward, lexpath, strpath, block, skipper: skipper
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
