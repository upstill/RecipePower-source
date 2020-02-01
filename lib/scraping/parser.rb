require 'scraping/seeker.rb'

=begin
# The ParseOut class is for nodes in the abstract syntax tree accumulated by the parser.
# At the end of a successful parse, the root ParseOut element can be used to modify the DOM
class ParseNode
  attr_reader :seeker, # The seeker that succeeded in matching
              :children, # Child ParseNodes
              :token # Token for applying to the DOM

  def initialize seeker, children, token=nil
    @seeker = seeker;
    @children = children
    @token = token
  end

  # Apply the results of the parse to the Nokogiri scanner
  def apply nokoscanner
    @children.each { |child| child.apply nokoscanner }
    nokoscanner.enclose_tokens(@seeker.head_stream, @seeker.rest, @token) if @token
  end
end
=end

class Parser
  # This is the DSL for parsing a recipe. The parsing engine, however, doesn't really concern recipes per se. It only
  # takes a grammar and a token generator and, if successful, creates an abstract syntax tree that just denotes what range of
  # tokens went into each match. In the case of a NokoScanner token generator, that syntax tree can be used to modify the
  # corresponding Nokogiri tree to mark each successful range of tokens with its element.
  #
  # The syntax tree is a hash, where the keys are elements of the language (a 'token'), and the value is a 'specification',
  # describing how to match that entity
  # The keys are symbols. THEY WILL ALSO BE USED TO IDENTIFY THE MATCH IN THE NOKOGIRI TREE
  #   by enclosing the found content in a <div class="rp_elmt #{token}">
  # Specifications can be of several types:
  # -- A String is matched literally
  # -- A Symbol is either a token with another entry in the grammar, or a special token with algorithmic meaning in
  #   the engine. None of the latter are currently defined, so all symbols must have entries in the grammar
  #   NB: The use of a symbol as specification at the top level (ie., token1: token2 ) would
  #   be redundant (unless token2 is a special token), since it does nothing but declare an alias
  # -- A Class is a subclass of Seeker that takes responsibility for producing a match and returning itself if found.
  #   (see the "abstract" class declaration of Seeker for details)
  # -- A RegExp is consulted for a match in text
  # -- An Array gives a sequence of specifications to match. This is the basis of recursion.
  # -- A Hash is a set of symbol/value pairs specifying instructions and constraints on what matches
  #     Generally speaking, a hash will include a :match key labeling a further specification, and other options for processing
  #     the set. Alternatively, a :tag may be specified
  #    match: denotes the token or tokens to match. For matching an array, this option is redundant if nothing else is
  #       being specified, i.e. token: { match: [a, b, c] } is no different from token: [a, b, c]. It's only
  #       needed if other elements of the hash (key/value pairs) are needed to assert constraints.
  #    tag: means to match a Tag from the dictionary, with the tag type or types given as the value. (Any of the type
  #       specifiers supported by the Tag class--integer, symbol or name--can be used as the type or element of the array)
  #       NB: matching a tag can consume more than one string token in the stream
  #    regexp: specifies a string that will be converted to a regular expression and applied to the next token.
  #       NB: this is redundant with respect to { match: /regexp/ } but lends itself to persistence
  #    seeker: specifies a subclass of Seeker (or a string naming that class) that will handle matching. Options to the
  #       seeker may be passed in an accompanying options: hash
  #       Also redundant wrt { match: Class } but works for persistence
  #
  #   By default, the members of an array are to be matched, in order, with material intervening between them
  #       ignored. Further flags below modify this behavior when set to 'true'. For convenience/syntactic sugar, any of
  #       these flags may be used in place of 'match'
  #    checklist: the array of items may be found in any order. The set matches when all its items (exc. optional ones) match
  #    repeating: stipulates that the set should be matched repeatedly; effectively a wildcard marker
  #    or: matches when ANY among the set matches (tried in order)
  #
  # Other options apply to both singular and collective matches:
  #    list: expects a series of matches on the given specification, interspersed with ',' and
  #       terminated with 'and' or 'or'. If the option is set to a string, that's used as the terminator
  #    optional: stipulates that the match is optional.
  #       For convenience/syntactic sugar, { optional: :token } is equivalent to { match: :token, optional: true }
  #    start: specifies a match that will begin a search, without consuming the match
  #    bound: gives a match that terminates the process, for example an EOL token. The given match is NOT consumed: the
  #       stream reverts to the beginning of the matched bound. This is useful,
  #       for example, to terminate processing at the end of a line, while leaving the EOL token for subsequent processing
  #    within_css_match: stipulates that the match is to be found within a part of the Nokogiri tree given by the CSS selector.
  #       Presumably this is used to exploit site-(or format)-specific style markers
  #       Notice that once a page is parsed and tokens marked in the DOM, there is an implicit :within_css_match to the stipulated
  #       token ("div.rp_elmt.#{token}"). Of course, when first parsing an undifferentiated document, no such markers
  #       are found. But they eventually get there anyway.
  @@DefaultGrammar = {
      rp_recipelist: { repeating: :rp_recipe },
      rp_recipe: {
          match: [
              { optional: :rp_title },
              :rp_inglist ,
              { checklist: [
                  { optional: :rp_author },
                  { optional: :rp_prep_time },
                  { optional: :rp_cook_time },
                  { optional: :rp_total_time },
                  { optional: :rp_serves },
                  { optional: :rp_author },
                  { optional: :rp_yield }
              ] },
          ]
      },
      # Hopefully sites will specify how to find the title in the extracted text
      rp_title: { accumulate: Regexp.new('^.*$'), within_css_match: 'h1' }, # Match all tokens within an <h1> tag
      rp_author: { match: [ Regexp.new('Author'), { accumulate: Regexp.new('^.*$') } ],  atline: true },
      rp_prep_time: { atline: [ Regexp.new('Prep'), { optional: ':' }, :rp_time ] },
      rp_cook_time: { atline: [ Regexp.new('Cook'), { optional: ':' }, :rp_time ] },
      rp_total_time: { atline: [ Regexp.new('Total'), { optional: ':' }, :rp_time ] },
      rp_time: [ :rp_num, 'min' ],
      rp_yield: { atline: [ Regexp.new('Makes'), { optional: ':' }, :rp_amt ] },
      rp_serves: { atline: [ Regexp.new('Serves'), { optional: ':' }, :rp_num ] },
      rp_inglist: {
          # The ingredient list(s) for a recipe
          match: { repeating: { :match => :rp_ingline, atline: true, optional: true } }
      },
      rp_ingline: {
          match: [
              {optional: [:rp_amt_with_alt, {optional: 'each'} ] },
              {optional: :rp_presteps},
              :rp_ingspec,
              {optional: :rp_ing_comment}, # Anything can come between the ingredient and the end of line
          ],
          bound: "\n"},
      rp_ing_comment: { optional: { accumulate: Regexp.new('^.*$') }, bound: "\n" }, # NB: matches even if the bound is immediate
      rp_amt_with_alt: [:rp_amt, {optional: :rp_altamt}] , # An amount may optionally be followed by an alternative amt enclosed in parentheses
      rp_amt: {# An Amount is a number followed by a unit (only one required)
               or: [
                   [:rp_num, :rp_unit],
                   :rp_num,
                   :rp_unit,
                   { match: AmountSeeker }
               ]
      },
      rp_altamt: ["(", :rp_amt, ")"],
      rp_presteps: { tag: 'Condition', list: true }, # There may be one or more presteps (instructions before measuring)
      rp_ingspec: { or: [:rp_ingalts, :rp_ingname] },
      rp_ingname: { tag: 'Ingredient' },
      rp_ingalts: { match: :rp_ingname, orlist: true },
      rp_num: NumberSeeker,
      rp_unit: { tag: 'Unit' }
  }

  def initialize noko_scanner_or_nkdoc_or_nktokens, grammar = nil, lexaur = nil
    if grammar.is_a?(Lexaur)
      grammar, lexaur = nil, grammar
    end
    grammar ||= @@DefaultGrammar.clone
    yield(grammar) if block_given? # This is the chance to modify the default grammar
    gramerrs = []
    Parser.grammar_check(grammar ) { |error| gramerrs << error }
    if gramerrs.present?
      raise 'Provided grammar has errors: ', *gramerrs
    end
    @grammar = grammar
    @lexaur = lexaur if lexaur
    @stream = case noko_scanner_or_nkdoc_or_nktokens
              when NokoScanner
                noko_scanner_or_nkdoc_or_nktokens
              when String
                NokoScanner.from_string noko_scanner_or_nkdoc_or_nktokens
              when NokoTokens
                NokoScanner.new noko_scanner_or_nkdoc_or_nktokens
              else
                raise "Trying to initialize Parser with #{noko_scanner_or_nkdoc_or_nktokens.class.to_s}"
              end
  end

  # Match the spec (which may be a symbol referring to a grammar entry), to the current location in the stream
  def match spec, at=@stream
    match_specification at, spec
  end

  # Scan down the stream, one token at a time, until the block returns true or the stream runs out
  def seek stream=@stream, spec={}
    unless stream.is_a?(NokoScanner)
      stream, spec = @stream, stream
    end
    while stream.more?
      if mtch = (block_given? ? yield(stream) : match(spec, stream))
        return mtch
      end
      stream = stream.rest
    end
  end

  # Advance the stream past the seeker result
  def advance seeker
    @stream = seeker.tail_stream
  end

  # Match a stream to a grammar, starting with an initial token. Since this method is re-entrant, we allow the
  # first call to set the grammar to be used in matching
  # Match by applying the grammar to the stream, attempting to match 'token' at the current position
  # 'options' are those specified in the reference to this token in the grammar
  # If successful, return a Seeker which gives the abstract parse tree in terms of token ranges in the text
=begin
  def self.match stream, token, options={}
    @@DefaultGrammar = (grammar_check(options[:grammar]) if options[:grammar]) || @@DefaultGrammar
    @lexaur = options[:lexaur] if options[:lexaur]
    match_specification stream, @@DefaultGrammar[token], token, options.except(:grammar)
  end
=end

  # Run an integrity check on the grammar, calling the block when an error is found
  def self.grammar_check grammar
    def self.check_entry entry, grammar
      case entry
      when Symbol
        unless grammar[entry]
          raise "Grammar has no entry for '#{entry}'"
        end
      when Class # A class is assumed to be fine
        unless entry.ancestors.include?(Seeker)
          raise "Seeker specification #{entry} is not a Seeker"
        end
      when Array # An array expands to its individual members
        entry.map { |member| self.check_entry member, grammar }
      when Hash
        if list = entry[:match] || (entry[:optional] if entry[:optional] != true)
          self.check_entry list, grammar
        end
        if tagtype = entry[:tag]
          if !Tag.typenum(tagtype)
            raise "Tag specifier is of unknown type #{tagtype}"
          end
        end
        if re = entry[:regexp]
          re = Regexp.new re
          unless re.is_a?(Regexp)
            raise "Regexp #{re} is invalid"
          end
        end
        if seeker = entry[:seeker]
          unless seeker.ancestors.include?(Seeker) || seeker.constantize(seeker)
            raise "Seeker specification '#{seeker}' is not a Seeker"
          end
        end

      end
    end
    grammar.keys.each do |key|
      self.check_entry grammar[key], grammar
    end if grammar
    grammar
  end

  private

  # Match a single specification to the provided stream, whether the spec is given directly in the grammar or included in a list.
  # Return a Seeker for the result that includes:
  # -- the beginning stream,
  # -- the succeeding stream,
  # -- a labeling token for the result, and
  # -- any children
  #
  # The 'spec' itself can come as disparate datatypes:
  #    -- a Symbol is expanded by lookup in the @@grammer, which provides a "real" spec. The symbol is then used as the token
  #    -- a String is tokenized and matched against tokens in the stream
  #    -- a Regexp is matched against the next token in the stream
  #    -- an Array provides an ordered list of specs; the list will be matched according to flags in the context
  #    -- a Hash is a spec in itself, providing its own context. It is interpreted as though it appeared directly in
  #        the grammar (which it probably should)
  #    -- a Class is presumed to be a subclass of Seeker, or at least has a 'match' class method which
  #         performs a match against the stream and returns a Seeker-like object
  #
  # The 'context' hash provides flags stipulating how the match should proceed:
    #    list: expects a series of matches on the given specification, interspersed with ',' and
    #       terminated with 'and' or 'or'. If the option is set to a string, that's used as the terminator
    #    optional: stipulates that the match is optional.
    #       For convenience/syntactic sugar, { optional: spec } is equivalent to { match: spec, optional: true }
    #    bound: gives a match that terminates the process, for example an EOL token. The given match is NOT consumed: the
    #       stream reverts to the beginning of the matched bound. This is useful,
    #       for example, to terminate processing at the end of a line, while leaving the EOL token for subsequent processing
    #    within_css_match: stipulates that the match is to be found within a part of the Nokogiri tree given by the CSS selector.
    #       Presumably this is used to exploit site-(or format)-specific style markers
    #       Notice that once a page is parsed and tokens marked in the DOM, there is an implicit :within_css_match to the stipulated
    #       token ("div.rp_elmt.#{token}"). Of course, when first parsing an undifferentiated document, no such markers
    #       are found. But they eventually get there anyway, either via successful parsing or user intervention.
  def match_specification scanner, spec, token=nil, context={}
    if token.is_a?(Hash)
      token, context = nil, token
    end
    found = nil
    if context[:repeating] # Match the spec repeatedly until EOF
      matches = []
      while scanner.peek && (found = match_specification( scanner, spec, context.except(:repeating))) do # No token except what the spec dictates
        if found.empty?
          scanner = found.tail_stream.rest # scanner.rest # Advance and continue scanning
        else
          matches << found
          scanner = found.tail_stream
        end
      end
      return Seeker.new(matches.first.head_stream, matches.last.tail_stream, token, matches) if matches.present? # Token only applied to the top level
    end
    if context[:atline]
      start_scanner = scanner.clone
      until scanner.atline? do
        if scanner.peek
          scanner = scanner.rest
        else
          return (Seeker.new start_scanner, scanner.rest, token if context[:optional])
        end
      end
      return match_specification(scanner, spec, token, context.except( :atline))
    end
    if context[:within_css_match]  # Use a stream derived from a CSS match in the Nokogiri DOM
      subscanners = scanner.within_css_matches context[:within_css_match]
      founds = []
      subscanners.each do |subscanner|
        found = match_specification subscanner, spec, token, context.except(:repeating, :within_css_match)
        if found && !found&.empty?  # Find the first valid result, or list all
          if context[:repeating]
            founds << found
          else
            found.tail_stream.encompass scanner
            return found # Singular result requires no higher-level parent
          end
        end
      end
      # In order to preserve the current stream placement while recording the found stream placement,
      # we return a single seeker with no token and matching children
      return founds.present? ?
                 Seeker.new(founds.first.head_stream, founds.last.tail_stream, token, founds) :
                 (Seeker.new(scanner, scanner, token, founds) if context[:optional])
    end
    if context[:start] # Advance the scan to the point matching the spec
      match = seek(scanner) { |scanner| match_specification scanner, context[:start] }
      scanner = scanner.goto(match.head_stream) if match
      found = match_specification scanner, spec, token, context.except(:start)
    end
    if context[:bound]
      # Terminate the search when the given specification is matched, WITHOUT consuming the match
      # Foreshorten the stream and recur
      # match = match_specification scanner, options[:bound]
      match = seek(scanner) { |scanner| match_specification scanner, context[:bound] }
      if match
        if seeker = match_specification( (scanner.except match.head_stream), spec, token, context.except(:bound))
          seeker.head_stream.encompass scanner ; seeker.tail_stream.encompass scanner # Restore the length of the head and tail
        end
      else # No bound found => proceed as normal, without the :bound specifier
        seeker = match_specification scanner, spec, token, context.except(:bound)
      end
        return seeker
    end
    if context[:accumulate] # Collect matches as long as they're valid
      while child = match_specification(found&.tail_stream || scanner, spec, token) do # TagSeeker.match(scanner, opts.slice( :lexaur, :types))
        if found
          found.tail_stream = child.tail_stream
        else
          found = child
        end
      end
      return found || (Seeker.new scanner, scanner, token if context[:optional]) # Leave an empty result for optional if not found
    end
    if context[:orlist]
      # Get a series of zero or more tags of the given type(s), each followed by a comma and terminated with 'and' or 'or'
      children = []
      start_scanner = scanner
      while child = match_specification(scanner, spec) do # TagSeeker.match(scanner, opts.slice( :lexaur, :types))
        children << child
        scanner = child.tail_stream
        case scanner.peek
        when 'and', 'or'
          # We expect a terminating entity
          if child = match_specification(scanner.rest, spec)
            children << child
            found = Seeker.new start_scanner, child.tail_stream, token, children
            break
          end
        when ','
          scanner = scanner.rest
        else # No delimiter subsequent: we're done. This allows for a singular list, but also doesn't require and/or
          break
        end
      end
      return found || (Seeker.new start_scanner, start_scanner, token if context[:optional]) # Leave an empty result for optional if not found
    end
    found =
    case spec
    when Symbol
      match_specification scanner, @grammar[spec], spec
    when String
      StringSeeker.match scanner, string: spec, token: token
    when Array
      # The context is distributed to each member of the list
      match_list scanner, spec, token, context
    when Hash
      match_hash scanner, spec, token
    when Class # The match will be performed by a subclass of Seeker
      spec.match scanner, context.merge(token: token, lexaur: @lexaur)
    when Regexp
      RegexpSeeker.match scanner, regexp: spec, token: token
    end
    # Return an empty seeker even if no match was found, as long as the match was declared optional
    found || (Seeker.new scanner, scanner, token if context[:optional]) # Leave an empty result for optional if not found
  end

  # Take an array of specifications and match them according to the context :checklist, :repeating, or :or. If no option,
  # seek to satisfy all specifications in the array, in order, once.
  def match_list start_stream, list_of_specs, token=nil, context={}
    if token.is_a?(Hash)
      token, context = nil, token
    end
    scanner = start_stream
    children = []
    end_stream = start_stream
    # Individual elements get the same context as the list as a whole, except for the list-processing options
    distributed_context = context.except :checklist, :repeating, :or
    case
    when context[:checklist] # All elements must be matched, but the order is unimportant
      list_of_specs.each do |spec|
        return if !(child = match_specification start_stream, spec, distributed_context) # Options get distributed down
        end_stream = child.tail_stream if child.tail_stream.pos > end_stream.pos
        children << child
      end
    when context[:repeating] # The list will be matched repeatedly until the end of input
      # Note: If there's no bound, the list will consume the entire stream
      while child = match_list(end_stream, list_of_specs, context.except(:repeating)) do
        children << child
        end_stream = child.tail_stream
      end
      return if children.empty?
    when context[:or]  # The list is taken as an ordered set of alternatives, any of which will match the list
      list_of_specs.each do |spec|
        if child = match_specification(scanner, spec, token, distributed_context)
          return child.token == token ? child : Seeker.new(start_stream, child.tail_stream, token, [child])
        end
      end
      return
    else # The default case: an ordered list of items to match
      list_of_specs.each do |spec|
        if !(child = match_specification end_stream, spec, distributed_context)
          return nil
        end
        end_stream = child.tail_stream
        children << child
      end
    end
    Seeker.new start_stream, end_stream, token, children
  end

  # Extract a specification and options from a hash. We analyze out the target spec (item or list of items to match),
  #   and the remainder of the input spec is context for the matcher.
  # This is where the option of asserting a list with :checklist, :repeating and :or options is interpreted.
  def match_hash scanner, inspec, token=nil
    if token.is_a?(Hash)
      token, context = nil, token
    end
    spec = inspec.clone
    # Check for an array to match
    if flag = [  :checklist, # All elements must be matched, but the order is unimportant
                 :repeating, # The spec will be matched repeatedly until the end of input
                 :atline, # match must start at the beginning of a line; matching scans until positioned at a line break
                 :or, # The list is taken as an ordered set of alternatives, any of which will match the list
                 :orlist, # The item will be repeatedly matched in the form of a comma-separated, 'and'/'or' terminated list
                 :accumulate, # Accumulate matches serially in a single child
                 :optional # Failure to match is not a failure
              ].find { |flag| spec[flag] }
            match = spec[flag]
    elsif match = spec[:tag] # Special processing for :tag specifier
      # Important: the :repeating, :accumulate and :orlist options will have been applied at a higher level
      return TagSeeker.match scanner, lexaur: @lexaur, token: token, types: match
    elsif match = spec[:regexp]
      match = Regexp.new match
    else
      match = spec.delete :match
    end
    match = spec.delete :match if match == true # If any of the above appeared as flags, get match from the :match value
    # We've extracted the specification to be matched into 'match', and use what's left as context for matching
    match_specification(scanner, match, token, spec) if match
  end
end
