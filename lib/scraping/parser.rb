require 'scraping/seeker.rb'
require 'enumerable_utils.rb'

class Parser
  attr_reader :grammar

  @@TokenTitles = {
      :rp_title => 'Title',
      :rp_ingline => 'Ingredient Line Item',
      :rp_inglist => 'Ingredient List',
      :rp_amt => 'Amount',
      :rp_num => '#',
      :rp_unit => 'Unit',
      :rp_presteps => 'Conditions',
      :rp_condition => 'Condit. Name',
      :rp_ingspec => 'Ingredients',
      :rp_ingname => 'Ingred. Name',
      :rp_instructions => 'Instructions',
  }

  # The default grammar is initialized by config/initializers/parser.rb
  def self.init_grammar grammar={}
    @@DefaultGrammar = grammar
  end

  # How should the token be enclosed?
  def self.tag_for_token token
    case token.to_sym
    when :rp_recipelist, :rp_recipe
      'div'
    when :rp_inglist
      'ul'
    when :rp_ingline
      'li'
    else
      'span'
    end
  end

  # Provide a list of tokens available to match
  def tokens
    @grammar.keys
  end

  def lexaur
    types = deep_collect(@grammar, :tag) | deep_collect(@grammar, :tags)
    @lexaur ||= Lexaur.from_tags *types
  end

  def self.token_to_title token
    @@TokenTitles[token] || "Unnamed Token #{token.to_s}"
  end

  def self.title_to_token title

  end

  # If the token has a grammar entry for a Tag, return said tag type
  def self.tagtype token
    if spec = @@DefaultGrammar[token.to_sym]
      spec[:tag]
    end
  end

  def initialize noko_scanner_or_nkdoc_or_nktokens, lex = nil, grammar_mods={}
    lex, grammar_mods = nil, lex if lex.is_a?(Hash)
    @grammar = @@DefaultGrammar.clone
    modify_grammar grammar_mods
    yield(@grammar) if block_given? # This is the chance to modify the default grammar further
    gramerrs = []
    @atomic_tokens = Parser.grammar_check(@grammar) { |error| gramerrs << error }
    if gramerrs.present?
      raise 'Provided grammar has errors: ', *gramerrs
    end
    @grammar.freeze
    @lexaur = lex if lex
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

  # Revise the default grammar by specifying new bindings for tokens
  # 'gm' is a hash:
  # -- keys are tokens in the grammar
  # -- values are hashes to be merged with the existing entries
  def modify_grammar gm
    def cleanup_entry token, entry
      return {} if entry.nil?
      return entry.map { |subentry| cleanup_entry token, subentry } if entry.is_a?(Array)
      # Convert a reference to a Seeker class to the class itself
      return entry.constantize if entry.is_a?(String) && entry.match(/Seeker$/)
      return entry unless entry.is_a?(Hash)
      # Syntactic sugar: these flags may specify the actual match. Make this explicit
      [
        :checklist, # All elements must be matched, but the order is unimportant
        :or, # The list is taken as an ordered set of alternatives, any of which will match the list
        :repeating, # The spec will be matched repeatedly until the end of input
        :orlist, # The item will be repeatedly matched in the form of a comma-separated, 'and'/'or' terminated list
        # :accumulate, # Accumulate matches serially in a single child
        :optional # Failure to match is not a failure
      ].each do |flag|
        if entry[flag] && entry[flag] != true
          entry[:match], entry[flag] = entry[flag], true
        end
      end
      entry[:match] = cleanup_entry :match, entry[:match] if entry[:match]
      keys = entry.keys.map &:to_sym # Ensure all keys are symbols
      [
          %i{ bound terminus }, # :bound and :terminus are exclusive options
          %i{ atline inline },  # :atline and :inline are exclusive options
          %i{ in_css_match at_css_match after_css_match } # :in_css_match, :at_css_match and :after_css_match are exclusive options
      ].each do |flagset|
        if (wrongset = (keys & flagset))[1]
          wrongstring, flagstring = [ wrongset, flagset ].map { |list|
            '\'' + list[0..-2].join("', '") + "' and '#{list.last}'"
          }
          raise "Error: grammar entry for #{token} has #{wrongstring} flags. (Only one of #{flagstring} allowed)."
        end
      end
      entry
    end # cleanup_entry
    # Do 
    def merge_entries original, mod
      return original unless mod && mod != {}
      return mod unless original&.is_a?(Hash)
      mod.each do |key, value|
        if value.nil?
          original.delete key
        else
          original[key] = value.is_a?(Hash) ? merge_entries(original[key], value) : value
        end
      end
      original
    end
    @grammar.keys.each do |key|
      key = key.to_sym
      entry = cleanup_entry key, @grammar[key]
      mod = cleanup_entry key, gm[key]
      @grammar[key] = merge_entries entry, mod # Allows elements to be removed
    end
  end

  # Match the spec (which may be a symbol referring to a grammar entry), to the current location in the stream
  def match spec, at=@stream
    matched = match_specification at, spec
    matched
  end

  # Scan down the stream, one token at a time, until the block returns true or the stream runs out
  def seek stream=@stream, spec={}
    unless stream.is_a?(NokoScanner)
      stream, spec = @stream, stream
    end
    while stream.more?
      mtch = (block_given? ? yield(stream) : match(spec, stream))
      return mtch if mtch.success?
      stream = mtch.next
    end
  end

  # Match a stream to a grammar, starting with an initial token. Since this method is re-entrant, we allow the
  # first call to set the grammar to be used in matching
  # Match by applying the grammar to the stream, attempting to match 'token' at the current position
  # 'options' are those specified in the reference to this token in the grammar
  # If successful, return a Seeker which gives the abstract parse tree in terms of token ranges in the text

  # Run an integrity check on the grammar, calling the block when an error is found.
  # As a side effect, generate a list of grammar entries that don't need secondary parsing
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
        if entry.slice( :in_css_match, :at_css_match, :after_css_match).count > 1
          raise 'Entry has more than one of :in_css_match, :at_css_match, and :after_css_match'
        end
        if tagtype = entry[:tag] || entry[:tags]
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
    # atomic_tokens collects the set of tokens for pre-parsed elements which aren't further analyzed
    atomic_tokens = {}
    grammar.keys.each do |key|
      begin
        self.check_entry grammar[key], grammar
      rescue Exception => e
        puts "Error in grammar [:#{key}]: " + e.to_s
      end
      atomic_tokens[key] = true if (grammar[key].is_a?(Hash) && (grammar[key][:tag] || grammar[key][:tags])) || [ :rp_title, :rp_ing_comment ].include?(key)
    end if grammar
    atomic_tokens
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
  #    -- nil (no match) means to match anything. (Presumably there will be other constraints bounding the match.)
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
    #    in_css_match: the search is constrained to the contents of the first node matching the associated CSS selector
    #    at_css_match: the search advances to the first node matching the associated CSS selector
    #    after_css_match: the search starts immediately after the first node matching the associated CSS selector
    #        NB: the three css matchers may appear in context with the :repeating flag; in that case, the search proceeds
    #         in parallel on all matching nodes. (multiple matches from :at_css_match do not overlap: after the first,
    #         each one foreshortens the previous one)
    #       Notice that once a page is parsed and tokens marked in the DOM, there is an implicit :in_css_match to the stipulated
    #       token ("div.rp_elmt.#{token}"). Of course, when first parsing an undifferentiated document, no such markers
    #       are found. But they eventually get there anyway, either via successful parsing or user intervention.
  def match_specification scanner, spec, token=nil, context={}
    if token.is_a?(Hash)
      token, context = nil, token
    end
    # Get the token from the context if necessary
    if !token && (token = context[:token])
      context = context.except :token
    end
    found = nil
    # Intercept a section that has already been parsed (or previously declared)
=begin
    if @atomic_tokens[token] && nokonode = scanner.parent_tagged_with(token)
      return Seeker.new scanner, scanner.past(nokonode), token
    end
=end
    if context[:atline] || context[:inline] # Skip to either the next newline character, or beginning of <p> or <li> tags, or after <br> tag--whichever comes first
      toline = scanner.toline(context[:inline], context[:inline] || context[:atline]) # Go to the next line, possibly limiting the scanner to that line
      return Seeker.failed(scanner, scanner.end, context) unless toline # No line to be found: skip the whole scanner
      return Seeker.failed(toline, toline.end, context) unless toline.more? # Trivial reject for an empty line
      match = match_specification(toline, spec, token, context.except(:atline, :inline))
      match.tail_stream = scanner.past(toline) if context[:inline] # Skip past the line
      return match.encompass(scanner)  # Release the line-end limitation
    end
    if context[:parenthetical]
      after = ParentheticalSeeker.match(scanner) do |inside|
        match = match_specification(inside, spec, token, context.except(:parenthetical))
      end
      return match ? Seeker.new(scanner, after, token, [match]) : Seeker.failed(scanner, after, context)
    end
    if context[:in_css_match] || context[:at_css_match] || context[:after_css_match] # Use a stream derived from a CSS match in the Nokogiri DOM
      subscanner = scanner.on_css_match(context.slice(:in_css_match, :at_css_match, :after_css_match))
      return Seeker.failed(scanner, context.except(:enclose)) unless subscanner # There is no such match in prospect
      match = match_specification subscanner, spec, token, context.except(:in_css_match, :at_css_match, :after_css_match)
      match.tail_stream = scanner.past(subscanner) if context[:in_css_match]  # Skip past the element
      return match.encompass(scanner)  # Release the limitation to element bounds
    end
    # The general case of a bounded search: foreshorten the stream to the boundary
    if terminator = (context[:bound] || context[:terminus])
      # Terminate the search when the given specification is matched, WITHOUT consuming the match
      # Foreshorten the stream and recur
      match = seek(scanner.rest) do |subscanner|
        match_specification subscanner, terminator
      end
      scannable = match&.success? ?
                      scanner.except( context[:bound] ? match.head_stream : match.tail_stream ) :
                      scanner
      return match_specification(scannable, spec, token, context.except(:bound, :terminus)).encompass(scanner)
    end
    if context[:repeating] # Match the spec repeatedly until EOF
      matches = []
      start_scanner = scanner
      # Unless working from a css match, scan repeatedly
=begin
      scanner.for_each(context.slice :atline, :inline, :in_css_match, :at_css_match, :after_css_match) do |scanner|
        match = match_specification scanner, spec, context.except(:repeating, :keep_if)
        matches << match.if_retain
        match.next
      end
=end
      while scanner.peek do # No token except what the spec dictates
        match = match_specification scanner, spec, context.except(:repeating, :keep_if)
        matches << match.if_retain
        scanner = (scanner == match.tail_stream) ? match.tail_stream.rest : match.tail_stream # next
      end
      # In order to preserve the current stream placement while recording the found stream placement,
      # we return a single seeker with no token and matching children
      matches.compact!
      if context[:enclose] == :non_empty # Consider whether to keep a repeater that turns up nothing
        return Seeker.failed(matches.first&.head_stream || start_scanner,
                             matches.last&.tail_stream || scanner, token, context.except(:enclose)) if matches.all?(&:hard_fail?)
        while matches.present? && matches.last.hard_fail? do
          matches.pop
        end
      end
      return case matches.count
             when 0
               Seeker.failed start_scanner, scanner, token, context
             when 1
               match = matches.first
               token.nil? || token == match.token ?
                   match :
                   Seeker.new(match.head_stream, match.tail_stream, token, matches)
             else
               Seeker.new(matches.first.head_stream, matches.last.tail_stream, token, matches) # Token only applied to the top level
             end
    end
    if context[:orlist]
      # Get a series of zero or more tags of the given type(s), each followed by a comma and terminated with 'and' or 'or'
      children = []
      start_scanner = scanner
      probe = scanner
      while probe.more? do
        case probe.peek
        when ',', 'and', 'or'
          child = match_specification scanner.except(probe), spec
          return Seeker.failed(start_scanner, child.tail_stream, token, context.merge(children: [child])) if !child.success?
          children << child
          break if probe.peek != ','
          scanner = probe.rest
        when '(' # Seek matching parenthesis
          if pr = ParentheticalSeeker.match(probe)  # Skip past the parenthetical
            probe = pr
            next
          end
        end
        probe = probe.rest
      end
=begin
      while scanner.more? do # TagSeeker.match(scanner, opts.slice( :lexaur, :types))
        child = match_specification scanner, spec
        return Seeker.failed(start_scanner, child.tail_stream, token, context.merge(children: [child])) if !child.success?
        children << child
        scanner = child.next
        case scanner.peek
        when 'and', 'or'
          # We expect a terminating entity
          child = match_specification scanner.rest, spec
          if child.success?
            children << child
            break
          else
            return Seeker.failed(start_scanner, child.head_stream, token, context.merge(children: (children + [child])))
          end
        when ','
          scanner = scanner.rest
        else # No delimiter subsequent: we're done. This allows for a singular list, but also doesn't require and/or
          break
        end
      end
=end
      if children.present?
        return Seeker.new(start_scanner, children.last.tail_stream.rest, token, children)
      else
        return Seeker.failed(start_scanner, token, context)
      end
    end

    # Finally, if no modifiers in the context, just match the spec
    found =
    case spec
    when nil # nil spec means to match the full contents
      Seeker.new scanner, scanner.rest(-1), token
    when Symbol
      # If there's a parent node tagged with the appropriate grammar entry, we just use that
      match_specification scanner, @grammar[spec], spec, context
    when String
      StringSeeker.match scanner, string: spec, token: token
    when Array
      # The context is distributed to each member of the list
      match_list scanner, spec, token, context
    when Hash
      match_hash scanner, spec, token, context
    when Class # The match will be performed by a subclass of Seeker
      spec.match scanner, context.merge(token: token, lexaur: lexaur)
    when Regexp
      RegexpSeeker.match scanner, regexp: spec, token: token
    end
    # Return an empty seeker if no match was found. (Some Seekers may return nil)
    found || Seeker.failed(scanner, token, context) # Leave an empty result for optional if not found
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
    distributed_context = context.except :checklist, :repeating, :or, :optional
    case
    when context[:checklist] # All elements must be matched, but the order is unimportant
      list_of_specs.each do |spec|
        scanner = start_stream
        best_guess = nil
        while scanner.more? && !(child = match_specification scanner, spec, distributed_context).success? do
          best_guess = child if child.enclose? # Save the last child to enclose
          scanner = child.next # Skip past what the child consumed
        end
        return best_guess if best_guess&.hard_fail?
        children << child.if_succeeded
        end_stream = child.tail_stream if child.tail_stream.pos > end_stream.pos # We'll set the scan after the last item
      end
    when context[:repeating] # The list will be matched repeatedly until the end of input
      # Note: If there's no bound, the list will consume the entire stream
      while end_stream.more? do
        child = match_list end_stream, list_of_specs, context.except(:repeating)
        children << child.if_succeeded
        end_stream = child.tail_stream # next
      end
    when context[:or]  # The list is taken as an ordered set of alternatives, any of which will match the list
      list_of_specs.each do |spec|
        child = match_specification start_stream, spec, token, distributed_context
        if child.success?
          return (token.nil? || child.token == token) ? child : Seeker.new(start_stream, child.tail_stream, token, [child])
        end
      end
      return Seeker.failed(start_stream, token, context) # TODO: not retaining children discarded along the way
    else # The default case: an ordered list of items to match
      list_of_specs.each do |spec|
        child = match_specification end_stream, spec, distributed_context
        children << child.if_retain
        end_stream = child.tail_stream
        if child.hard_fail?
          return Seeker.failed((children.first || child).head_stream,
                               end_stream,
                               token,
                               child.retain? ? context.merge(children: children.keep_if(&:'retain?')+[child]) : context)
        end
      end
    end
    # If there's only a single child and no token, just return that child
    children.compact!
    (children.count == 1 && token.nil?) ?
        children.first :
        Seeker.new(start_stream, end_stream, token, children)
  end

  # Extract a specification and options from a hash. We analyze out the target spec (item or list of items to match),
  #   and the remainder of the input spec is context for the matcher.
  # This is where the option of asserting a list with :checklist, :repeating and :or options is interpreted.
  def match_hash scanner, inspec, token=nil, context={}
    if token.is_a?(Hash)
      token, context = nil, token
    end
    spec = inspec.clone
    # Check for an array to match
    if flag = [  :checklist, # All elements must be matched, but the order is unimportant
                 :repeating, # The spec will be matched repeatedly until the end of input
                 :or, # The list is taken as an ordered set of alternatives, any of which will match the list
                 :orlist, # The item will be repeatedly matched in the form of
                 :parenthetical, # Match inside parentheses
                 :optional # Failure to match is not a failure
              ].find { |flag| spec.key?(flag) && spec[flag] != true }
            to_match, spec[flag] = spec[flag], true
    elsif to_match = spec[:tag] || spec[:tags] # Special processing for :tag specifier
      # TagSeeker parses a single tag
      # TagsSeeker parses a list of the form "tag1, tag2 and tag3" into a set of tags
      klass = spec[:tag] ? TagSeeker : TagsSeeker
      # Important: the :repeating option will have been applied at a higher level
      return klass.match(scanner, lexaur: lexaur, token: token, types: to_match) ||
          Seeker.failed(scanner, token, spec)
    elsif to_match = spec[:regexp]
      to_match = Regexp.new to_match
    else
      to_match = spec.delete :match
    end
    to_match = spec.delete :match if to_match == true # If any of the above appeared as flags, get match from the :match value
    # We've extracted the specification to be matched into 'to_match', and use what's left as context for matching
    match = match_specification scanner, to_match, token, spec
    return match if match.success?
    token ||= match.token
    # If not successful, reconcile the spec that was just answered with the provided context
    if (really_enclose = context[:enclose]) == :non_empty
      really_enclose = match.children&.all?(:hard_fail?)
    end
    really_enclose ||= match.enclose? && (match.tail_stream != match.head_stream)
    return Seeker.failed(match.head_stream,
                         match.tail_stream,
                         token,
                         enclose: (really_enclose ? true : false),
                         optional: ((context[:optional] || match.soft_fail?) ? true : false))
  end
end
