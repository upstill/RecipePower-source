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
    # puts "Creating Lexaur from tags of type(s) '" + types.join("', '") + '\'.'
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
    strings = strings.map { |str| Tag.normalize_name(str).split('-') }.flatten
    return nil if strings.empty?
    first = strings.shift
    strings.empty? ? terminals[first] : nexts[first]&.find(strings)
  end

  # Drive a Lexaur using a stream. The stream only needs to implement three methods:
  # -- #peek provides the word at the head of the stream
  # -- #first peaks at the head but also advances the stream, consuming the first element
  #     for the remainder
  # -- #rest returns a stream for the stream minus the head.
  # The block is called with the data at the end of the path
  def chunk stream, skipper: -> (stream){ stream }, &block
    chunk1 stream, -> (onward, lexpath, strpath) {
      terms = (lexpath.last.terminals[strpath.last] if lexpath.last)
      block.call terms, onward if block_given? && terms.present?
    }, skipper: skipper
  end

  # Distribute subterms about a delimiter token,
  # skipping tokens as performed by :skipper
  # This is a recursive function for accumulating results, collected as:
  # -- lexpath: a path down the Lexaur tree driven by processed tokens
  # -- strpath: the tokens driving that path
  # -- result: a LexResult object which takes proposed paths and saves the longest one until its #report method is called
  # -- reporter: a Proc (passed as a block on the initial call) which takes each result as 1) terminal
  #       data from the lexpath, and 2) the location in the stream where the path ended
  def distribute stream, skipper: -> (stream){ stream }, lexpath: [self], strpath: [], result: LexResult.new(stream), reporter: nil, &block
    reporter ||= block
    operand = ''
    # Find at least one path down the tree driven by the incoming tokens.
    # #chunk1 invokes this block once each time a sequence hits, longest first
    # furthest_terms, furthest_stream, longest_path = [], stream, []
    while lex = lexpath.pop do
      lex.chunk1 stream, -> (onwrd, lexpth, strpth) {
        # A completed path has been found => check for delimiter, and offer the path to subsequent tokens
        # terms: the data found at the terminus of the search
        # stream: the stream as consumed in proceeding down the tree
        # newpath: the lexaur path from the root to the matched data
        # We want the longest path and the furthest stream that produces a term
        result.propose onwrd, lexpth, strpth
        if %w{ , and or }.include? onwrd.peek
          operand = onwrd.peek if onwrd.peek != ','
          # ...and we might be able to extend the current longest_path with tokens from the subsequent result
          further = lex.distribute(onwrd = onwrd.rest,
                          skipper: skipper,
                          lexpath: lexpath+lexpth,
                          strpath: strpath+strpth,
                          reporter: reporter)
          result.extend further if further
        end
      }, skipper: skipper
    end
    # Return the result for extension purposes, only if the sequel passes muster
    return result if result.report { |data, stream_start, stream_end| reporter.call data, stream_start, stream_end, operand if data }
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
      substrs = Tag.normalize_name(token).split '-'
      tracker = self
      if substrs.present?
        head = substrs.pop || '' # Save the last substring
        # Descend the tree for each substring, depending on there being a head marker at each step along the way
        substrs.each do |substr|
          tracker = tracker.nexts[substr]
          return if tracker.nil?
          lexpath.push tracker
        end
        # Peek ahead and consume any tokens which are empty in the normalized name
        onward, unskipped = elide(stream.rest, skipper)
        # Recursively continue along the stream and down the tree
        if nxt = tracker.nexts[head]
          nxt.chunk1(onward, lexpath, strpath + [head], block, skipper: skipper)
          # Once there are no more matches along/down, we consume the head of the stream.
          # NB This has the effect of returning the longest match first
          # Report back the terminals even if absent
          if tracker.terminals[head]
            block.call(unskipped, lexpath, strpath + [head]) # The block must check for acceptance and return true for the process to end
          end
        elsif tracker.terminals[head]
          block.call(unskipped, lexpath, strpath + substrs + [head]) # The block must check for acceptance and return true for the process to end
        else
          block.call(elide(stream, skipper).first, lexpath[0...strpath.length], strpath) # The block must check for acceptance and return true for the process to end
        end
      else # This token didn't bear anything of relevance to Tag.normalize_name
        block.call(stream, lexpath[0..-2], strpath) # The block must check for acceptance and return true for the process to end
      end
    end
  end

  private

  # Our own #split function which (currently) separates out punctuation
  def split string_or_strings
    strings = string_or_strings.is_a?(String) ? tokenize(string_or_strings) : string_or_strings
    strings.map { |str| Tag.normalize_name(str).split('-') }.flatten
  end

  # Take an opportunity to pass up unwanted/irrelevant tokens
  def elide stream, skipper
    unskipped = stream
    stream = skipper.call stream
    case stream.peek
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
