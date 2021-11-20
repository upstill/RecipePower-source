require 'scraping/lexaur.rb'

# Class for applying patterns to streamed input based on a trigger at the token level
class Patternista
  def initialize tag_lex
    @string_lex = Lexaur.new # mapping from (possibly successive) tokens in the intput to patterns to raise for them
    @tag_patterns = {} # Patterns applied to a hit on a tag, indexed by tagtype
    @tag_lex = tag_lex
    @re_patterns = {} # Patterns applied to hits on regular expressions
    @metapatterns = {} # Patterns applied when a pattern matches, looking for higher-level matches
  end

  # Include the given pattern among available matchers; test it when the trigger appears
  def assert pattern, trigger=pattern.trigger
    list =
    case trigger
    when String # String to match
      @string_lex.take trigger, pattern
      return
    when Array  # ...for collection of triggers, record the pattern as a response to each
      trigger.each { |tr| assert pattern, tr }
      return
    when Integer # ...for type of Tag
      typesym = Tag.typesym trigger
      # @tag_patterns[typesym] = @tag_patterns[typesym] ? (@tag_patterns[typesym] | [pattern]) : [pattern]
      # (@tag_patterns[typesym] ||= []) |= [pattern]
      @tag_patterns[typesym] ||= []
    when Regexp # Regular Expression to match on stream
      # @re_patterns[trigger] = @re_patterns[trigger] ? (@re_patterns[trigger] | [pattern]) : [pattern]
      # (@re_patterns[trigger] ||= []) |= [pattern]
      @re_patterns[trigger] ||= []
    when Symbol # Token to be a match against the grammar, triggered when that grammar entry is matched
      # @metapatterns[trigger] = @metapatterns[trigger] ? (@metapatterns[trigger] | [pattern]) : [pattern]
      # (@metapatterns[trigger] ||= []) |= [pattern]
      @metapatterns[trigger] ||= []
    end
    # Don't accept a redundant pattern
    list << pattern unless list.find { |member| member.eq? pattern }
  end

  # Look for the patterns that match the given stream.
  # If 'token' is specified, match only that token
  # At each position in the stream, apply one or more patterns whose trigger matches the contents
  # of the stream at that position.
  # Return an array of found seekers
  def scan stream
    stream = stream.clone
    results = []
    while stream.more? do
      if result = scan1(stream, stream.all)
        results << result
        stream = stream.goto result.tail_stream
      else
        stream.first
      end
    end
    results # Seeker.new(results.first.head_stream, results.last.tail_stream, results) if results.present?
  end

  # Heart of pattern matching: For a stream at a given point, compare the content at that point to
  # a set of triggers. For each trigger that matches, try to apply its associated pattern
  def scan1 stream, context = stream.all
    # Collect patterns triggered by the stream at the current position
    seekers = []

    # Check all the string triggers
    @string_lex.chunk(stream) do |patterns, onward|
      # onward is the stream AFTER the match. The pattern matcher wants the matching stream
      contents = stream.except onward
      # patterns is the collection of patterns that were triggered
      # onward is the stream AFTER the trigger thus matched
      # NB This block may be called multiple times, for successive triggers of decreasing length (in tokens)
      seekers += patterns.collect { |pattern|
        pattern.match contents, context
      }.compact
    end

    # Check for tag matches
    @tag_lex.chunk(stream) do |tag_ids, onward|
      # onward is the stream AFTER the match. The pattern matcher wants the matching stream
      contents = stream.except onward
      # tag_ids denotes the set of tags found in the stream, by database ID
      # onward is the stream AFTER the tags collected at that length
      # NB This block may be called multiple times, for successive tag sets of decreasing length (in tokens)
      seekers += Tag.where(id: tag_ids).to_a.collect { |tag|
        if patterns = @tag_patterns[tag.typesym]
          patterns.collect { |ptn|
            ptn.match contents, context
          }.compact
        end
      }.compact.flatten
    end

    # Match the current stream against the Regexp's used as keys in @re_patterns
    @re_patterns.each do |re, ptns|
      if stream.peek&.match(re)
        contents = stream.except stream.rest # One token only
        seekers += ptns.collect { |ptn|
          ptn.match contents, context
        }.compact
      end
    end

    # Now there's a collection of patterns; probe the stream with each pattern in turn

    # Now seekers is a collection of Seeker objects, one for each pattern matched
    # First, check the token for each match as a trigger in a metamatch
    seekers = seekers.collect { |seeker|
      if mps = @metapatterns[seeker.token]
        mps.map { |pattern| pattern.match seeker, context }
      else
        seeker # seeker is unaffected
      end
    }.flatten.compact

    if block_given?
      # Call the block with all the matches, longest to shortest
      seekers.sort_by(&:bound).each { |match| yield match }
    else
      # Finally, pick the match with the longest extent
      seekers.max_by &:bound
    end
  end
end
