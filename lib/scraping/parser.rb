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
    nokoscanner.enclose_tokens(@seeker.head, @seeker.rest, @token) if @token
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
          repeating: [ "\n", :rp_ingline ]
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
      rp_ingspec: { or: [:rp_ingname, :rp_ingalts] },
      rp_ingname: { tag: 'Ingredient' },
      rp_ingalts: { match: :rp_ingname, orlist: true },
      rp_num: AmountSeeker,
      rp_unit: { tag: 'Unit' }
  }

  @@Grammar = @@DefaultGrammar

=begin
  def initialize start_streamgrammar=@@Grammar
    yield(grammar) if block_given? # This is the chance to modify the default grammar
    gramerrs = []
    grammar_check( grammar ) { |error| gramerrs << error }
    if gramerrs.present?
      raise 'Provided grammar has errors: ', *gramerrs
    end
    @grammar = grammar
  end
=end

  # Match a stream to a grammar, starting with an initial token
  # Match by applying the grammar to the stream, attempting to match 'token' at the current position
  # 'options' are those specified in the reference to this token in the grammar
  # If successful, return a Seeker which gives the abstract parse tree in terms of token ranges in the text
  def self.match stream, token, opts={}
    if opts[:grammar] && grammar_check(opts[:grammar])
      @@Grammar = @@DefaultGrammar
    end
    match_specification(stream, @grammar[token], opts)
  end

  # Run an integrity check on the grammar, calling the block when an error is found
  def self.grammar_check grammar
    def check_entry entry, grammar
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
        entry.map { |member| check_entry member, grammar }
      when Hash
        if list = entry[:match] || (entry[:optional] if entry[:optional] != true)
          check_entry list, grammar
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
      check_entry grammar[key], grammar
    end
    true
  end

  # parse: apply the grammar to the stream represented by 'scanner', attempting to match 'token' at the current position
  # 'options' are those specified in the reference to this token in the grammar
  # If successful, return a Seeker which gives the abstract parse tree in terms of token ranges in the text
  def self.match_grammar scanner, token, options={}
    # Seek to match the specification; if it suceeds, tag the tree with the token
    match_specification scanner, @grammar[token], token, options.merge(token: token)
  end

  # Match a single specification, whether given directly in the grammar or included in a list.
  # Return a ParseNode for the beginning stream, the succeeding stream, and any children
  def self.match_specification scanner, spec, token=nil, options={}
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
    if token.is_a?(Hash)
      token, options = nil, token
    end
    if options[:list]
      # Match the spec repeatedly
      matches = []
      while (match = match_specification scanner, options.except(:list), token) do
        matches << match
        scanner = match.end_scanner
      end
      return new(matches.first.start_scanner, matches.last.end_scanner, token, matches)
    end
    if options[:bound] # Terminate the search when the given specification is matched, WITHOUT consuming the match
      # Foreshorten the stream and recur
      match = match_specification scanner, options[:bound]
      seeker = match_specification (scanner - match.rest), options.except(:bound), token
      seeker.head += scanner ; seeker.tail += scanner # Restore the length of the head and tail
      return seeker
    end
    if options[:within_css_match] # Use a stream derived from a CSS match in the Nokogiri DOM
    end
    if options[:unremarked] # Don't modify the DOM to reflect the result
    end
    inherited_options = options.slice :bound
    found =
    case spec
    when Symbol
      self.match scanner, spec, options
    when String
      StringSeeker.match scanner, string: spec
    when Array
      match_list scanner, spec, token, options
    when Hash
      match_hash scanner, spec, token, options
    when Class # The match will be performed by a subclass of Seeker
      spec.match scanner, options.merge(token: token)
    end
    # Return an empty seeker if no match but the match is optional
    found || (new scanner, scanner, token if options[:optional]) # Leave an empty result for optional if not found
  end

  private
  # Take an array of specifications and match them according to the options
  def match_list start_scanner, specs, token=nil, options={}
    if token.is_a?(Hash)
      token, options = nil, token
    end
    scanner = start_scanner
    children = []
    end_scanner = start_scanner
    case
    when options[:checklist] # All elements must be matched, but the order is unimportant
      specs.each do |spec|
        child = match_specification start_scanner, spec   # Options do NOT get passed down in recursion
        return if !child
        end_scanner = child.end_scanner if child.end_scanner.pos > end_scanner.pos
        children << child
      end
    when options[:repeating] # The list will be matched repeatedly until the end of input
      # If there's no bound, the list will consume the entire stream
      until !end_scanner.more?  do
        child = match_list end_scanner, specs, options
        children << child
        end_scanner = child.end_scanner
      end
      return if children.empty?
    when options[:or]  # The list is taken as an ordered set of alternatives, any of which will match the list
      child = nil
      specs.find { |spec| child = match_specification scanner, spec }
      if child
        children = [child]
      else
        return
      end
    else # The default case: an ordered list of items to match
      specs.each do |spec|
        child = match_specification end_scanner, spec   # Options do NOT get passed down in recursion
        return if !child
        end_scanner = child.end_scanner
        children << child
      end
    end
    new start_scanner, end_scanner, token, children
  end

  # Process a specification given as a hash. We analyze out the target (item or list of items to match),
  #   and a set of options for the matcher.
  def match_hash scanner, hsh, token=nil, options={}
    if token.is_a?(Hash)
      token, options = nil, token
    end
    spec = nil
    case
    when spec = hsh.delete(:checklist) # All elements must be matched, but the order is unimportant
      options[:checklist] = true
    when spec = hsh.delete(:repeating) # The list will be matched repeatedly until the end of input
      # Warning: if there's no :bound option, the list will consume the entire stream
      options[:repeating] = true
    when spec = hsh.delete(:or)  # The list is taken as an ordered set of alternatives, any of which will match the list
      options[:or] = true
    else
      spec = hsh.delete :match
    end
    spec = hsh.delete :match if spec == true
    # We've extracted the specification
    match_specification scanner, spec, token, hsh # options.merge(hsh)
  end
end
