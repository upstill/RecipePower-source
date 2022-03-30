require 'scraping/seeker.rb'
require 'scraping/patternista.rb'
require 'scraping/scan_pattern.rb'
require 'scraping/grammar_mods.rb'
require 'enumerable_utils.rb'

# TODO: 'orange slice', i.e., ingredient FOLLOWED BY unit
# '2 tablespoons juice from 1 lemon'
# '1 teaspoon sherry (or other wine) vinegar' Recipe 15644
# 'Needles from one, 6-inch section of fresh rosemary' Recipe 15644
# '1 1/2 cups diced autumn mushrooms, such as blewits and maitake' Recipe 15644
# '1 garlic clove', 1 salmon fillet (Recipe #2176)
# Detecting multiple ingredient lists and labelling them: Recipe 15636: Mixed vegetable and potato fritters with harissa
# "Cook 1 hr 20 min", ibid
# :rp_author should opt for tag(s) lookup
# Recipe #15663 Intermediate: Mandarin and Screwdriver (https://www.foodandwine.com/cocktails-spirits/mandarine-napoleon-cocktail-recipes)
#   an ounce and a half of vodka, half an ounce of Mandarine Napoléon, an ounce of fresh mandarin orange juice, and half an ounce of simple syrup.
# Recipe 15663(public) Tofu and Kale Salad With Avocado, Grapefruit, and Miso-Tahini Dressing
# 1 (14-ounce; 400g) block firm (non-silken) tofu
# 3/4 ounce (about 1/4 cup; 20g) za'atar, divided
# 1 tablespoon (15ml) white or yellow miso paste
# 1 tablespoon (15ml) juice from 1 lemon
# Recipe 15662(public) Real-Deal Mapo Tofu
# 1 1/2 pounds medium to firm silken tofu, cut into 1/2-inch cubes
# Recipe 15662(public) Sheet-Pan Spiced Cauliflower and Tofu With Ginger Yogurt
# 1 large (2 3/4-pound; 1.25kg) head cauliflower
# Recipe #15673(public) Fish-Fragrant Eggplants...
# 1 pound 5 ounces (600g) eggplants (1–2 large)
class Parser
  include GrammarMods
  attr_reader :grammar, :patternista, :benchmarks

  @@TokenTitles = {
      :rp_title => 'Title',
      :rp_ingline => 'Ingredient Line Item',
      :rp_inglist => 'Ingredient List',
      :rp_amt => 'Amount',
      :rp_num => '#',
      :rp_unit => 'Unit',
      :rp_presteps => 'Conditions',
      :rp_condition_tag => 'Condit. Name',
      :rp_ingspec => 'Ingredients',
      :rp_ingredient_tag => 'Ingred. Name',
      :rp_instructions => 'Instructions',
  }

  # The default grammar is initialized by config/initializers/parser.rb
  def self.init_grammar grammar={}
    @@DefaultGrammar = grammar
    @@GrammarYAML = grammar.to_yaml
  end

  def self.init_triggers *trigger_pattern_pairs
    @@TriggerPatternPairs = trigger_pattern_pairs
  end

  # Provide a copy of the grammar as initialized
  def self.initialized_grammar
    YAML.load @@GrammarYAML
  end

  # How should the token be enclosed?
  def self.tag_for_token token
    case token.to_sym
    when :rp_recipelist, :rp_recipe, :rp_instructions, :rp_recipe_section # :rp_inglist, :rp_ingline
      'div'
    when :rp_inglist
      'ul'
    when :rp_ingline
      'li'
    else
      'span'
    end
  end

  # How should a successful match on the token be enclosed in the DOM?
  # There are defaults, but mainly it's also a function of the grammar, which is site-dependent
  def tag_for_token token
    case token
    when :rp_inglist
      'ul'
    when :rp_ingline
      'li'
    else
      if (grammar_hash = @grammar[token.to_sym]).is_a? Hash
        if selector = grammar_hash[:in_css_match]
          selector.split('.').first.if_present
        elsif grammar_hash[:inline]
          'span'
        end
      end || Parser.tag_for_token(token)
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

  def patternista
    return @patternista if @patternista
    @patternista = Patternista.new lexaur
    @trigger_map.each do |token, triggerz|
      # When the trigger is encountered during the scan, seek a match for the grammar entry
      next if triggerz.blank?
      @patternista.assert GrammarPattern.new(token, self), triggerz
    end
    @@TriggerPatternPairs.each do |trigger_patterns|
      trigger = trigger_patterns.first
      # The remainder of the declaration is patterns associated with the trigger
      trigger_patterns[1..-1].each { |pattern| @patternista.assert GrammarPattern.new(pattern, self), trigger }
      # NB: currently, only grammar references (tokens) are accepted as patterns,
      # but there's no reason that a pattern in the same format as a grammar entry
      # can't be used instead.
    end
    @patternista
  end

  def self.token_to_title token, default: nil
    @@TokenTitles[token] || default || "Unnamed Token #{token.to_s}"
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
    @trigger_map = {}
    @grammar = Parser.finalized_grammar(mods_plus: grammar_mods) do |key, trigger|
      @trigger_map[key] = trigger 
    end
    yield(@grammar) if block_given? # This is the chance to modify the default grammar further
    gramerrs = []
    # @atomic_tokens =
    Parser.grammar_check(@grammar) { |error| gramerrs << error }
    if gramerrs.present?
      raise 'Provided grammar has errors: ', *gramerrs
    end
    if report_on
      puts ">>>>>>>>>>> Freezing grammar:"
      @grammar.keys.each { |token| puts ":#{token} =>", indent_lines(@grammar[token]) }
    end
    @grammar.freeze
    @lexaur = lex if lex
    self.stream = noko_scanner_or_nkdoc_or_nktokens
  end

  def cache_init
    @cache = Hash.new
    @cache_tries = 0
    @cache_hits = 0
    @cache_misses = 0
    @cache_on = true
  end

  def benchmarks_init
    @benchmarks = {}
  end

  def stream=noko_scanner_or_nkdoc_or_nktokens
    @stream =
        case noko_scanner_or_nkdoc_or_nktokens
        when NokoScanner, StrScanner
          noko_scanner_or_nkdoc_or_nktokens
        else
          NokoScanner.new(noko_scanner_or_nkdoc_or_nktokens)
        end
  end

  def scan stream=@stream
    patternista.scan stream
  end

  # Can a token validly be parsed out at the current position of the stream?
  def valid_to_match? token, stream
    return true if token == :rp_title ||
        token == :rp_recipe ||
        (enclosing_classes = stream.enclosing_classes).empty?
    !enclosing_classes.include?(token)
  end

  # Match the spec (which may be a symbol referring to a grammar entry), to the current location in the stream
  def match token, stream: @stream, singular: false, reparse: false
    puts ">>>>>>>>>>> Entering Parse for :#{token} on '#{stream.to_s(trunc: 100, nltr: true)}'" if report_on
    safe_stream = stream.clone
    matched = nil
    if (reparse || valid_to_match?(token, safe_stream)) && (ge = grammar[token])
      if ge.is_a?(Hash)
        ge = ge.except :match_all if singular
        token = ge.delete(:token) || token
      end
      if @benchmarks
        @cache_tries = @cache_hits = @cache_misses = 0
        cache_on = true
        NestedBenchmark.do_log = true
        NestedBenchmark.measure("Matched with parser cache ON") do
          match_specification safe_stream, ge, token
        end
        times = NestedBenchmark.last_times
        benchmark = {
            cache_on: {
                tries: @cache_tries, hits: @cache_hits, misses: @cache_misses}.
                merge(utime: times.utime, stime: times.stime, total: times.total, real: times.real)
        }

        @cache_tries = @cache_hits = @cache_misses = 0
        safe_stream = stream.clone
        cache_on = false
        NestedBenchmark.measure("Matched with parser cache OFF") do
          matched = match_specification safe_stream, ge, token
        end
        times = NestedBenchmark.last_times
        benchmark[:cache_off] = {tries: @cache_tries, hits: @cache_hits, misses: @cache_misses}.
            merge utime: times.utime, stime: times.stime, total: times.total, real: times.real
        # Add the times and counts to any ongoing benchmark, if any
        @benchmarks = benchmark_sum @benchmarks, benchmark
      else
        matched = match_specification safe_stream, ge, token
      end
    else
      matched = Seeker.failed safe_stream, token: token
    end
    matched if matched.success?
  end

  # Return the sum of the two benchmarks, leaving the operands untouched
  def benchmark_sum op1, op2=benchmarks
    rtnval = {}
    op1 ||= {}
    if op2.nil?
      # Simply copy op1 to the result
      op1&.each { |status, results| rtnval[status] = results.clone }
      return rtnval
    end
    op2.each do |status, results|
      if results.empty?
        rtnval[status] = op1[status]&.clone || {}
        next
      end
      if op1[status].present?
        rtnval[status] = {}
        results.each { |key, value|
          rtnval[status][key] = (v1 = op1[status][key]) ? v1+value : value
        }
      else
        rtnval[status] = results.clone
      end
    end
    rtnval
  end

  # Scan down the stream, one token at a time, until the block returns true or the stream runs out
  def seek stream=@stream, spec={}
    unless stream.is_a?(NokoScanner)
      stream, spec = @stream, stream
    end
    while stream.more?
      mtch = (block_given? ? yield(stream) : match(spec, stream: stream))
      if mtch
        return mtch if mtch.success?
        stream = mtch.next
      else
        stream = stream.rest
      end
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

  # Maintain instance variable controlling parse logging outside of testing
  def report_on
    @report_on || Rails.env.test? || Rails.env.development?
  end

  def report_on=bool
    @report_on = bool
  end

  private

  def indentation
    @indent ||= 0
    "|  " * @indent
  end

  def puts_indented str
    puts str.split("\n").collect { |line| indentation+line }.join("\n")
  end

  def report_enter *args
    puts_indented args.shift
    @indent += 1
    while args.present? do
      puts_indented args.shift
    end
  end

  def report_exit msg
    @indent -= 1
    puts_indented msg if msg.present?
  end

  # Cache support: results from #match_specification are cached on the
  # requested grammar entry (spec) and the location in the stream at which
  # the request takes place.

  def cache_on=yes
    @cache_on = yes
  end

  # Add the seeker to the cache
  def cache seeker, key
    @cache_on ? (@cache[key] = seeker.clone) : seeker
  end

  # Check the cache
  def cache_fetch key
    if @cache_on
      @cache_tries += 1
      if cached = @cache[key]
        @cache_hits += 1
      else
        @cache_misses += 1
      end
      cached
    end
  end

  def cache_key_for stream, spec:, token:, context:
    (context || {}).merge(range: stream.pos...stream.bound, token: token, spec: spec).hash
  end

  def cache_report
    return { tries: @cache_tries, hits: @cache_hits, misses: @cache_misses } if @cache_on
  end

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

    # Check the cache, if any
    if @cache_on
      @cache_tries += 1
      if (cache_key = cache_key_for scanner, spec: spec, token: token, context: context) &&
        (cached = cache_fetch(cache_key))
        return cached
      end
    end
    if context[:parenthetical]
      match = nil
      after = ParentheticalSeeker.match(scanner) do |inside|
        match = match_specification(inside, spec, token, context.except(:parenthetical))
      end
      return match ? Seeker.new(scanner, children: [match], bound: after.bound, token: token) : Seeker.failed(scanner, context)
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
      return match_specification(scannable, spec, token, context.except(:bound, :terminus)).bounded_by(scanner)
    end
    if context[:repeating] # Match the spec repeatedly until EOF
      matches = []
      start_scanner = scanner
      # Scan repeatedly
      while scanner.peek do # No token except what the spec dictates
        match = match_specification scanner, spec, context.except(:repeating, :keep_if)
        break unless match.retain?
        matches << match.if_retain
        # Start the next search just after the beginning of this one.
        scanner = scanner.goto match.bound
      end
      # Clip each match to its successor to prevent overlap
      starts = matches.map &:pos
      matches[0..-2].each_index { |ix| matches[ix].bound = starts[ix+1] if starts[ix+1] < bound } # matches[0..-2].each_index { |ix| matches[ix].tail_stream = matches[ix].tail_stream.except matches[ix+1].head_stream }
      # In order to preserve the current stream placement while recording the found stream placement,
      # we return a single seeker with no token and matching children
      return report_matches matches, token, spec, context, scanner, start_scanner
    end
    if context[:orlist]
      # Get a series of zero or more tags of the given type(s), each followed by a comma and terminated with 'and' or 'or'
      children = []
      start_scanner = scanner
      if context[:orlist] == :predivide
        # Rather than let the child delimit the list, pass successive restricted scanners
        children = scanner.partition.collect do |subscanner|
          match_specification subscanner, spec
        end
        children.keep_if &:success?
      else
        while scanner.more? do
          child = match_specification scanner, spec
          break if !child.success?
          children << child
          scanner = child.next
          if scanner.peek == '('
            # Discard parenthetical comments
            to_match = scanner.rest
            while to_match.more? && to_match.peek != ')' do
              to_match = to_match.rest
            end
            scanner = to_match.rest if to_match
          end
          case scanner.peek
          when 'and', 'or'
            # We expect a terminating entity
            child = match_specification scanner.rest, spec
            children << child if child.success?
            break
          when ','
            scanner = scanner.rest
          else # No delimiter subsequent: we're done. This allows for a singular list, but also doesn't require and/or
            break
          end
        end
      end
      return case children.count
      when 0
        Seeker.failed start_scanner, context.merge(token: token)
      when 1 # Don't create a new node with just one child
        children.first
      else
        Seeker.new start_scanner, children: children, token: token
      end
    end

    # Finally, if no modifiers in the context, just match the spec
    found =
    case spec
    when nil # nil spec means to match the full contents
      Seeker.new scanner, token: token
    when Symbol
      # If there's a parent node tagged with the appropriate grammar entry, we just use that
      hash = @grammar[spec]
      to_return = nil
      if report_on
        @break_level ||= 3
        str = scanner.to_s trunc: 100, nltr: true
        report_enter "Seeking :#{spec} on '#{str}'"
        to_return = match_specification scanner, hash, spec, context
        report_exit (to_return.success? ? "Found '#{to_return.to_s trunc: 200}' for :#{to_return.token}" : "Failed to find :#{spec} on '#{str}'") if report_on
      else
        to_return = match_specification scanner, hash, spec, context
      end
      cache to_return, cache_key
    when Hash
      match_hash scanner, spec, token, context
    when String
      StringSeeker.match scanner, string: spec, token: token, report_on: @report_on
    when Array
      # The context is distributed to each member of the list
      match_list scanner, spec, token, context
    when Class # The match will be performed by a subclass of Seeker
      spec.match scanner, context.merge(token: token, lexaur: lexaur, parser: self)
    when Regexp
      RegexpSeeker.match scanner, regexp: spec, token: token, report_on: @report_on
    end
    # Return an empty seeker if no match was found. (Some Seekers may return nil)
    found || Seeker.failed(scanner, context.merge(token: token)) # Leave an empty result for optional if not found
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
    distributed_context = context.except :checklist, :repeating, :or, :filter, :optional, :distribute
    case
    when context[:checklist] # All elements must be matched, but the order is unimportant
      list_of_specs.each do |spec|
        scanner = start_stream
        child = match_specification scanner, spec, distributed_context
=begin
        best_guess = nil
        while scanner.more? && !(child = match_specification scanner, spec, distributed_context).success? do
          best_guess = child if child.enclose? # Save the last child to enclose
          scanner = child.next # Skip past what the child rejected
        end
        best_guess ||= child
        return best_guess if best_guess&.hard_fail?
        next unless child
=end
        children << child.if_succeeded
        end_stream = child.tail_stream if child.tail_stream.pos > end_stream.pos # We'll set the scan after the last item
      end
    when context[:distribute] # The list will be matched repeatedly until the end of input
      # Rather than applying the list as a whole repeatedly, :distribute
      # applies the first repeatedly, then the second, etc., each time constraining
      # the next search to the following result. This allows [ :rp_title, nil ]
      # to match a title, followed by all content up to the next title.
      new_children = []
      list_of_specs = list_of_specs.clone
      while new_children.empty? && spec = list_of_specs.shift do
        end_stream = scanner
        # Probe for matches on the first spec
        while end_stream.more? &&
            (match = match_specification end_stream, spec, context.except(:distribute, :under)).success? do
          new_children.push match
          end_stream = match.tail_stream
        end
        break unless spec.is_a?(Hash) && spec[:optional]
      end
      children = [ new_children.compact ]
      # Now we have a collection of children due to the first spec
      while (spec = list_of_specs.shift) do
        new_children = []
        old_children = children.last
        old_children.each_index do |ix|
          intervening = scanner.between old_children[ix].result_stream, old_children[ix+1]&.result_stream
          new_children.push match_specification( intervening, spec, context.except(:distribute)).if_succeeded
        end
        children.push new_children
      end
      # Now children is an array of arrays
      # Turn the array structure
      collections = Array.new(children.first.count) { children.map &:shift }
      children = collections.map { |list|
        Seeker.new children: list.delete_if(&:nil?), token: context[:under] || token
      }
    when context[:repeating] # The list will be matched repeatedly until the end of input
      # Note: If there's no bound, the list will consume the entire stream
      while end_stream.more? do
        child = match_list end_stream, list_of_specs, context.except(:repeating)
        children << child.if_succeeded
        end_stream = child.tail_stream # next
      end
    when context[:filter]
      list_of_specs.each do |spec|
        child = match_specification end_stream, spec, distributed_context
        if child.success?
          children << child
          end_stream = child.tail_stream if child.tail_stream.pos > end_stream.pos # We'll set the scan after the last item
        end
      end
      return Seeker.failed(start_stream, context.merge(token: token)) unless children.present? # TODO: not retaining children discarded along the way
    when context[:or] # The list is taken as an ordered set of alternatives, any of which will match the list
      list_of_specs.each do |spec|
        child = match_specification start_stream, spec, token, distributed_context
        if child.success?
          return (token.nil? || child.token == token) ?
                     child :
                     Seeker.new( start_stream, children: [child], token: token, pos: start_stream.pos)
        end
      end
      return Seeker.failed(start_stream, context.merge(token: token)) # TODO: not retaining children discarded along the way
    else # The default case: an ordered list of items to match
      list_of_specs.each do |spec|
        child = match_specification end_stream, spec, distributed_context
        children << child.if_retain
        end_stream = child.tail_stream # end_stream.past child.tail_stream
        if child.hard_fail? # && !child.enclose?
          context = context.merge(children: children.keep_if(&:'retain?') + [child]) if child.retain?
          return Seeker.failed((children.first || child).head_stream, context.merge(token: token))
        end
      end
    end
    # If there's only a single child and no token, just return that child
    children = children.compact.map { |child| (child.token || child.children.empty?) ? child : child.children }.flatten(1).compact
    if children.count == 1 && token.nil?
      # If only one child, and no token is being asserted, simply promote the child
      # children.first.tail_stream = end_stream
      children.first
    elsif children.present?
      Seeker.new start_stream, children: children, token: token
    else
      Seeker.failed start_stream, token: token
    end
  end

  # Extract a specification and options from a hash. We analyze out the target spec (item or list of items to match),
  #   and the remainder of the input spec is context for the matcher.
  # This is where the option of asserting a list with :checklist, :repeating, :or and :filter options is interpreted.
  def match_hash scanner, inspec, token=nil, context={}
    if token.is_a?(Hash)
      token, context = nil, token
    end
    spec = inspec.clone
    if flag = [  :checklist, # All elements must be matched, but the order is unimportant
                 :repeating, # The spec will be matched repeatedly until the end of input
                 :or, # The list is taken as an ordered set of alternatives, any of which will match the list
                 :filter, # Like :or, but all matching elements are retained
                 # :orlist, # The item will be repeatedly matched in the form of
                 :parenthetical, # Match inside parentheses
                 :optional, # Failure to match is not a failure
                 :match_all,
                 :distribute # Execute search across list "in parallel"
              ].find { |flag| spec.key?(flag) && spec[flag] != true }
            to_match, spec[flag] = spec[flag], true
    elsif to_match = spec[:tag] || spec[:tags] # Special processing for :tag specifier
      # TagSeeker parses a single tag
      # TagsSeeker parses a list of the form "tag1, tag2 and tag3" into a set of tags
      klass = spec[:tag] ? TagSeeker : TagsSeeker
      # Important: the :repeating option will have been applied at a higher level
      return klass.match(scanner, lexaur: lexaur, token: token, types: to_match, report_on: @report_on) ||
          Seeker.failed(scanner, spec.merge(token: token))
    elsif to_match = spec[:regexp]
      to_match = Regexp.new to_match
    else
      to_match = spec.delete :match
    end
    to_match = spec.delete :match if to_match == true # If any of the above appeared as flags, get match from the :match value

    # Handle a repetitive spec (CSS matches, :match_all directive)
    if match = match_repeater( scanner, token, to_match, spec, context)
      return match
    else
      match = match_specification(scanner, to_match, token, spec)
    end
=begin  NB: This code has been moved into #match_repeater
    # We've extracted the specification to be matched into 'to_match', and use what's left as context for matching
    # If the parse is restricted, enumerate the matches and recur on each
    repeater = spec.slice(:atline, :inline, :in_css_match, :at_css_match, :after_css_match).compact # Discard any nil repeater specs
    # A repeater provides its own engine for repetition (e.g., a CSS match), in which case :match_all is a flag for taking every match
    # There should only be one repeater specification
    if repeater.present?
      # Hopefully we get a token for enclosing a result collection, in the :under spec
      spec = spec.except :atline, :inline, :in_css_match, :at_css_match, :after_css_match
      # Whether to enclose a failed result does not get passed down
      enclose = spec.delete :enclose
      last_scanner = scanner
      matches =
          scanner.for_each(repeater) do |subscanner|
            match = match_specification (last_scanner = subscanner), to_match, token, spec
            if match.success? || enclose
              # Keeping this match
              if context[:match_all]
                # If repeating, collect and carry on
                # match
                (repeater[:inline] || repeater[:in_css_match]) ?
                    match.clone_with(token: token, range: subscanner.range, enclose: enclose) :
                    match.clone_with(enclose: enclose)
              else
                # Singular match: just return
                return match.clone_with(stream: scanner)
                # return match.clone_with(stream: scanner, range: subscanner.range)
                # return repeater[:atline] ? match : match.clone_with(stream: scanner, range: subscanner.range)
              end
            else
              # Match not to be retained, whether failed or not => continue cycling
              next
            end
            #matches << match.clone_with(token: token, range: subscanner.range)
            #match = match.clone_with token: token, range: subscanner.range
          end
      return report_matches matches.compact,
                            (context[:under] || token),
                            spec,
                            spec.merge(enclose: enclose),
                            last_scanner,
                            scanner
    elsif context[:match_all]
      # ALL the matches, not just one.
      matches = []
      first_scanner = scanner
      while scanner.more? do
        match = match_specification scanner, to_match, token, spec.except(:enclose)
        break unless match.success?
        scanner = match.tail_stream # Release the subscanner's constraint on the result
        matches << match
      end
      match = report_matches matches, (context[:under] || token), to_match, inspec, first_scanner, scanner
    else
      # NB: a :retain directive is passed down
      match = match_specification scanner, to_match, token, spec
    end
=end
    return match if match.success?
    token ||= match.token
    # If not successful, reconcile the spec that was just answered with the provided context
    if (really_enclose = context[:enclose]) == :non_empty
      really_enclose = match.children&.all?(:hard_fail?)
    end
    really_enclose ||= match.enclose? && (match.size > 0)
    return Seeker.failed(scanner, # match.head_stream,
                         range: match.range, 
                         token: token,
                         enclose: (really_enclose ? true : false),
                         optional: ((context[:optional] || inspec[:optional] || match.soft_fail?) ? true : false))
  end

  # CSS matches, plus :atline and :inline and :match_all directives, call for multiple matches.
  # Here we're responsible for executing those and packaging them up into a single result seeker, if any
  def match_repeater scanner, token, to_match, spec, context
    repeater = spec.slice(:atline, :inline, :in_css_match, :at_css_match, :after_css_match).compact # Discard any nil repeater specs
    if repeater.present?
      # Hopefully we get a token for enclosing a result collection, in the :under spec
      spec = spec.except :atline, :inline, :in_css_match, :at_css_match, :after_css_match
      # Whether to enclose a failed result does not get passed down
      enclose = spec.delete :enclose
      last_scanner = scanner
      matches =
          scanner.for_each(repeater) do |subscanner|
            match = match_specification (last_scanner = subscanner), to_match, token, spec
            # We may have produced a useless match b/c we don't pass :non_empty down
            case enclose
            when :multiple # Needs more than one good child
              match.failed = true if match.children.count { |child| child.success? } < 2
            when :non_empty
              match.failed = true unless match.children.any? { |child| child.success? }
            end
            if match.success? || (enclose == true)
              # Keeping this match
              if context[:match_all]
                # If repeating, collect and carry on
                # match
                (repeater[:inline] || repeater[:in_css_match]) ?
                    match.clone_with(token: token, range: subscanner.range, enclose: enclose) :
                    match.clone_with(enclose: enclose)
              else
                # Singular match: just return
                return match.clone_with(stream: scanner)
                # return match.clone_with(stream: scanner, range: subscanner.range)
                # return repeater[:atline] ? match : match.clone_with(stream: scanner, range: subscanner.range)
              end
            else
              # Match not to be retained, whether failed or not => continue cycling
              next
            end
            #matches << match.clone_with(token: token, range: subscanner.range)
            #match = match.clone_with token: token, range: subscanner.range
          end
      report_matches matches.compact,
                     (context[:under] || token),
                     spec,
                     spec.merge(enclose: enclose),
                     last_scanner,
                     scanner
    elsif context[:match_all]
      # ALL the matches, not just one.
      matches = []
      first_scanner = scanner
      while scanner.more? do
        match = match_specification scanner, to_match, token, spec.except(:enclose)
        break unless match.success?
        scanner = match.tail_stream # Release the subscanner's constraint on the result
        matches << match
      end
      report_matches matches, (context[:under] || token), to_match, inspec, first_scanner, scanner
    end
  end

  def consolidate_inglines token, seekers
    return if token != :rp_ingline
    # An ingredient list needs special attention:
    # -- individual lines may have failed but still need to be retained
    # -- failed lines may represent labels of sublists
    seekers.each do |match|
      # Label detection: failed lines that are preceded by two <br> tags get converted to :rp_inglist_label
      next unless match.hard_fail?
      if (submatch = seek match.scanner_within, :rp_ingredient_tag)&.success?
        # Can find an ingredient in the line => enclose it within the line
        (match.children ||= []) << submatch
      elsif match.size < 4 # (match.tail_stream.pos - match.head_stream.pos) < 4
        match.token = :rp_inglist_label
      end
    end
    Seeker.new(children: seekers, token: :rp_inglist) if seekers.count > 1
  end

  # When matches have been generated by a multi-matching directive, resolve the collection here
  def report_matches matches, token, spec, context, scanner, start_scanner
    matches.compact!
    if context[:enclose] == :non_empty # Consider whether to keep a repeater that turns up nothing
      if matches.all? &:hard_fail?
        failed_range = (matches.last&.tail_stream || scanner).range
        return Seeker.failed start_scanner,
                             context.
                                 except(:enclose).
                                 merge(token: token, range: failed_range)
      end
    end
    consolidation = consolidate_inglines spec, matches
    return consolidation if consolidation
    # Default handling is to delete failed matches, then assess the remainder
    matches.keep_if &:retain?
    return case matches.count
           when 0
             Seeker.failed start_scanner, context.merge(range: scanner.range, token: token)
           when 1
             first_match = matches.first
             if token.nil? || token == first_match.token
               first_match.stream = start_scanner
               first_match
             else
               Seeker.new start_scanner, children: matches, token: token
             end
           else
             Seeker.new start_scanner, children: matches, token: token # Token only applied to the top level
           end
  end

end

# The ParserEvaluator provides analysis of the current (initialized) grammar. Methods:
# can_include? evaluates whether a token could appear as a child of a parent token.
class ParserEvaluator

  attr_reader :init_g

  def initialize
    @grammar_inclusions = {}
    @init_g = Parser.initialized_grammar
    @init_g.each { |token, entry| @grammar_inclusions[token] = scan_for_tokens(entry).uniq }
  end

  # Declare that an arbitrary inclusion is okay
  def can_include parent_token, child_token
    parent_token, child_token = parent_token.to_sym, child_token.to_sym
    @grammar_inclusions[parent_token] ||= []
    @grammar_inclusions[parent_token] |= [child_token] 
  end

# Evaluate whether child_token can appear as a child of parent_token.
  def can_include? parent_token, child_token, transitive = true
    # Does supe refer to sub in the grammar?
    # If stack is not nil, it is an array used to avoid circular recursion.
    def refers_to? supe, sub, stack=nil
      return unless (inclusions = @grammar_inclusions[supe])
      inclusions.include?(sub) ||
          stack && (stack.include?(sub) || inclusions.find { |inner| refers_to? inner, sub, stack+[sub] })
    end

    parent_token.nil? ||
        child_token.nil? ||
        refers_to?(parent_token.to_sym, child_token.to_sym, ([parent_token.to_sym] if transitive))
  end

  private

  def scan_for_tokens grammar_entry
    collected_tokens = []
    case grammar_entry
    when Array
      grammar_entry.each { |list_member| collected_tokens += scan_for_tokens list_member }
    when Symbol
      collected_tokens << grammar_entry if grammar_entry.to_s.match(/^rp_/)
    when Hash
      grammar_entry.each do |key, subentry|
        if key == :tags
          # Find the grammar entry that has a :tag key and the same string
          collected_tokens << @init_g.find { |token, entry| entry.is_a?(Hash) && entry[:tag] == subentry }&.first
        else
          collected_tokens += scan_for_tokens subentry
        end
      end
    end
    collected_tokens
  end
end
