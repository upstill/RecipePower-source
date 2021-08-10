
# A ScanPattern object maps from a trigger found in an input stream, to a larger sequence of tokens.
# It returns a Seeker object for a particular token.
class ScanPattern
  # A pattern is a sequence to be matched when a certain trigger appears in input.
  # -- trigger is known to the owning Patternista, saved as an instance variable for convenience
  # -- token is a symbol used to label the result
  # -- sequence is an array for a series of matches to perform, in which the trigger is embedded
  # output: if a match is found, return a Seeker whose token is that provided
  def initialize sequence, token
    @token = token
    # For convenience, split the sequence between elements before and after the trigger
    at = sequence.find_index { |elmt| elmt.is_a?(Hash) && elmt[:trigger] }
    @seq_before = sequence[0..at]
    @trigger = sequence[at][:trigger]
    @seq_after = sequence[(at+1)..-1]
  end

  # Employ our sequence to match input.
  # -- trigger_match is a seeker for the found trigger, which may encompass multiple tokens
  # -- context is a stream whose bounds define the possible range of the match (shorter is better)
  # return: if the match was found, a Seeker delimiting the tokens of the match, labelled with @token
  def match trigger_match, context = nil
    stream = trigger_match.is_a?(Seeker) ? trigger_match.head_stream : trigger_match
    context ||= stream.all
  end

end

# A GrammarPattern applies an entry from the grammar in lieu of an explicit pattern.
# When invoked, it attempts to match the grammar entry
class GrammarPattern < ScanPattern

  def initialize token, parser
    @to_match = token
    @parser = parser
  end

  # Employ our parser to match input when a trigger is identified in the course of scanning.
  # -- trigger_match is a seeker for the found trigger, which may encompass multiple tokens
  # -- context is a stream whose bounds define the possible range of the match (shorter is better)
  # return: if the match was found, a Seeker delimiting the tokens of the match, labelled with @token
  def match trigger_match, context = nil
    stream = trigger_match.is_a?(Seeker) ? trigger_match.head_stream : trigger_match
    context ||= stream.all
    # Now the grammar entry at @token will be matched by the @parser from the stream
    @parser.match @to_match, stream: stream.encompass(context), in_place: true
  end
end