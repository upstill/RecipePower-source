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

class ParserSeeker < Seeker
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
  #    bound: gives a match that terminates the process, for example an EOL token. The given match is NOT consumed: the
  #       stream reverts to the beginning of the matched bound. This is useful,
  #       for example, to terminate processing at the end of a line, while leaving the EOL token for subsequent processing
  #    within_css_match: stipulates that the match is to be found within a part of the Nokogiri tree given by the CSS selector.
  #       Presumably this is used to exploit site-(or format)-specific style markers
  #       Notice that once a page is parsed and tokens marked in the DOM, there is an implicit :within_css_match to the stipulated
  #       token ("div.rp_elmt.#{token}"). Of course, when first parsing an undifferentiated document, no such markers
  #       are found. But they eventually get there anyway.
  #    unremarked: stipulates that the matching material will not be marked in the DOM
  @@DefaultGrammar = {
      rp_recipe: {
          checklist: [
              { optional: :rp_title },
              { optional: :rp_author },
              { optional: :rp_yield },
              { match: :rp_inglist, repeating: true }
          ]
      },
      # Hopefully sites will specify how to find the title in the extracted text
      rp_title: { repeating: Regexp.new('^.*$'), within_css_match: 'h1' }, # Match all tokens within an <h1> tag
      rp_author: [],
      rp_yield: [],
      rp_makes: [],
      rp_inglist: {
          # The ingredient list(s) for a recipe
          match: { repeating: [ "\n", :rp_ingline ] }
      },
      rp_ingline: {
          match: [
              {optional: :rp_amt_with_alt},
              {optional: :rp_presteps},
              :rp_ingspec,
              {optional: :rp_ing_comment}, # Anything can come between the ingredient and the end of line
          ],
          bound: "\n"},
      rp_ing_comment: { optional: { regexp: '^.*$' }, repeating: true, unremarked: true, bound: "\n" }, # NB: matches even if the bound is immediate
      rp_amt_with_alt: [:rp_amt, {optional: :rp_altamt}] , # An amount may optionally be followed by an alternative amt enclosed in parentheses
      rp_amt: {# An Amount is a number followed by a unit (only one required)
               or: [
                   [:rp_num, :rp_unit],
                   :rp_num,
                   :rp_unit
               ]
      },
      rp_altamt: ["(", :rp_amt, ")"],
      rp_presteps: { tag: 'Process', list: true }, # There may be one or more presteps (instructions before measuring)
      rp_ingspec: { or: [:rp_ingalts, :rp_ingname] },
      rp_ingname: { tag: 'Ingredient' },
      rp_ingalts: { match: :rp_ingname, orlist: true },
      rp_num: NumberSeeker,
      rp_unit: { tag: 'Unit' }
  }

  @@Grammar = @@DefaultGrammar

  def initialize noko_scanner_or_nkdoc_or_nktokens, grammar=@@Grammar, lexaur = nil
    if !grammar.is_a?(Hash)
      grammar, lexaur = @@Grammar, grammar
    end
    yield(grammar) if block_given? # This is the chance to modify the default grammar
    gramerrs = []
    ParserSeeker.grammar_check( grammar ) { |error| gramerrs << error }
    if gramerrs.present?
      raise 'Provided grammar has errors: ', *gramerrs
    end
    @grammar = grammar
    @@Lexaur = lexaur if lexaur
    stream = (noko_scanner_or_nkdoc_or_nktokens if noko_scanner_or_nkdoc_or_nktokens.is_a?(NokoScanner)) ||
        NokoScanner.new(noko_scanner_or_nkdoc_or_nktokens)
    super stream, stream
  end

  # Apply the grammar to matching the token, which must exist as a key in the Grammar hash
  def match token
    self.children = []
    if match = ParserSeeker.match_specification(head_stream, @grammar[token], token)
      self.children = [ match ]
      self.tail_stream = match.tail_stream
      match
    end
  end

  def self.seek stream, spec={}
    while stream.more?
      if match = yield stream
        return match
      end
      stream = stream.rest
    end
  end

  # Match a stream to a grammar, starting with an initial token. Since this method is re-entrant, we allow the
  # first call to set the grammar to be used in matching
  # Match by applying the grammar to the stream, attempting to match 'token' at the current position
  # 'options' are those specified in the reference to this token in the grammar
  # If successful, return a Seeker which gives the abstract parse tree in terms of token ranges in the text
  def self.match stream, token, options={}
    @@Grammar = (grammar_check(options[:grammar]) if options[:grammar]) || @@DefaultGrammar
    @@Lexaur = options[:lexaur] if options[:lexaur]
    ParserSeeker.match_specification stream, @@Grammar[token], token, options.except(:grammar)
  end

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
    #    unremarked: stipulates that the matching material will not be marked in the DOM
  def self.match_specification scanner, spec, token=nil, context={}
    if token.is_a?(Hash)
      token, context = nil, token
    end
    if context[:within_css_match]  # Use a stream derived from a CSS match in the Nokogiri DOM
      scanners = scanner.within_css_matches context[:within_css_match]
      seekers = []
      scanners.each do |in_scanner|
        seeker = ParserSeeker.match_specification in_scanner, spec, token, context.except(:repeating, :within_css_match)
        unless seeker&.empty?
          seekers << seeker
          break unless context[:repeating] # Find the first valid result, or list all
        end
      end
      # In order to preserve the current stream placement while recording the found stream placement,
      # we return a single seeker with no token and matching children
      result =
        (context[:optional] ?
            Seeker.new(scanner, scanner, seekers) :
            Seeker.new(seekers.first.head_stream, seekers.last.rest_stream, seekers)) if seekers.present?
      return result
    end
    if context[:repeating] # Match the spec repeatedly
      matches = []
      while (found = ParserSeeker.match_specification scanner, spec, context.except(:repeating)) do # No token except what the spec dictates
        matches << found
        scanner = found.tail_stream
      end
      return Seeker.new(matches.first.head_stream, matches.last.tail_stream, token, matches) # Token only applied to the top level
    end
    if options[:bound] # Terminate the search when the given specification is matched, WITHOUT consuming the match
      # Foreshorten the stream and recur
      match = match_specification scanner, options[:bound]
      seeker = match_specification (scanner - match.rest), options.except(:bound), token
      seeker.head += scanner ; seeker.tail += scanner # Restore the length of the head and tail
      return seeker
    end
=begin
    if context[:unremarked] # Don't modify the DOM to reflect the result
    end
=end
    found =
    case spec
    when Symbol
      ParserSeeker.match scanner, spec
    when String
      StringSeeker.match scanner, string: spec, token: token
    when Array
      # The context is distributed to each member of the list
      ParserSeeker.match_list scanner, spec, token, context
    when Hash
      ParserSeeker.match_hash scanner, spec, token
    when Class # The match will be performed by a subclass of Seeker
      spec.match scanner, context.merge(token: token, lexaur: @@Lexaur)
    when Regexp
      RegexpSeeker.match scanner, regexp: spec, token: token
    end
    # Return an empty seeker even if no match was found, as long as the match was declared optional
    found || (Seeker.new scanner, scanner, token if context[:optional]) # Leave an empty result for optional if not found
  end

  private
  # Take an array of specifications and match them according to the context :checklist, :repeating, :or. If no option,
  # seek to satisfy all specifications in the array once.
  def self.match_list start_stream, list_of_specs, token=nil, context={}
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
        return if !(child = ParserSeeker.match_specification start_stream, spec, distributed_context) # Options get distributed down
        end_stream = child.tail_stream if child.tail_stream.pos > end_stream.pos
        children << child
      end
    when context[:repeating] # The list will be matched repeatedly until the end of input
      # Note: If there's no bound, the list will consume the entire stream
      until !end_stream.more? do
        child = match_list end_stream, list_of_specs, context.except(:repeating)
        children << child
        end_stream = child.tail_stream
      end
      return if children.empty?
    when context[:or]  # The list is taken as an ordered set of alternatives, any of which will match the list
      list_of_specs.each do |spec|
        if child = ParserSeeker.match_specification( scanner, spec, token, distributed_context)
          return child.token == token ? child : Seeker.new(start_stream, end_stream, token, [child])
        end
      end
      return
    else # The default case: an ordered list of items to match
      list_of_specs.each do |spec|
        return if !(child = ParserSeeker.match_specification end_stream, spec, distributed_context)
        end_stream = child.tail_stream
        children << child
      end
    end
    Seeker.new start_stream, end_stream, token, children
  end

  # Extract a specification and options from a hash. We analyze out the target spec (item or list of items to match),
  #   and the remainder of the input spec is context for the matcher.
  # This is where the option of asserting a list with :checklist, :repeating and :or options is interpreted.
  def self.match_hash scanner, inspec, token=nil
    if token.is_a?(Hash)
      token, context = nil, token
    end
    spec = inspec.clone
    # Check for an array to match
    case
    when match = spec[:checklist] # All elements must be matched, but the order is unimportant
      # process_as = :checklist
      spec[:checklist] = true
    when match = spec[:repeating] # The spec will be matched repeatedly until the end of input
      # Warning: if there's no :bound option, the list will consume the entire stream
      # process_as = :repeating
      spec[:repeating] = true
    when match = spec[:or]  # The list is taken as an ordered set of alternatives, any of which will match the list
      # process_as = :or
      spec[:or] = true
    when match = spec[:orlist] # The item will be repeatedly matched in the form of a comma-separated, 'and'/'or' terminated list
      spec[:orlist] = true
    when match = spec[:tag] # Special processing for :tag specifier
      # Important: the :repeating and :orlist options will have been applied at a higher level
      return TagSeeker.match scanner, lexaur: @@Lexaur, token: token, types: match
    else
      match = spec.delete :match
    end
    match = spec.delete :match if match == true # If any of the above appeared as flags, get match from the :match value
    # We've extracted the specification to be matched into 'match', and use what's left as context for matching
    ParserSeeker.match_specification(scanner, match, token, spec) if match
  end
end
