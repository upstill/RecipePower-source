require 'recipe.rb'
require 'scraping/parser.rb'
require 'recipe_page.rb'

class ParserServices
  attr_reader :parsed, # Trees of seeker results resulting from parsing and scanning, respectively
              :grammar_mods, # Modifications to be used on the parser beforehand
              :input,
              :match_benchmarks, # Retains the benchmarks for the last parse
              :scanner # The scanner associated with the current input

  delegate :nkdoc, to: :scanner # ...assuming it's a NokoScanner
  delegate :'success?', :find, :hard_fail?, :find_value, :value_for, :xbounds, to: :parsed

  def initialize entity: nil, token: nil, input: nil, lexaur: nil, grammar_mods: nil
    self.entity = entity # Object (ie., Recipe or RecipePage) to be parsed
    self.token = token
    self.input = input
    self.lexaur = lexaur
    self.grammar_mods = grammar_mods
  end

  # Simplified attempt to parse a string, with no grammar mods or entity, for use in the CLI
  def self.go string, tags: {}, token: :rp_ingline
    lexaur = Lexaur.from_tags
    # Ensure the presence of all given tags
    tags.each do |tagtype, tagnames|
      typenum = Tag.typenum tagtype.to_s.singularize.capitalize.to_sym
      [tagnames].flatten.each do |tagname|
        if tag = Tag.find_by(name: tagname, tagtype: typenum)
          puts "Tag '#{tag.name}' (#{tag.typename}##{tag.id}) already exists"
          next
        elsif (tags = Tag.strmatch(tagname, tagtype: typenum)).exists?
          tagnames = strjoin tags.pluck(:name).collect { |name| "'#{name}'"}
          puts "#{tags.count} #{Tag.typename typenum}/(#{typenum}) tags found that match #{tagname}: #{tagnames}"
        end
        puts "Asserting '#{tagname}' as tag of type #{Tag.typename typenum}/#{typenum}"
        tag = Tag.assert tagname, typenum
        lexaur.take tag.name, tag.id
        found = nil
        scanner = StrScanner.new tag.name
        lexaur.chunk(scanner) { |data| found ||= data }
        puts "Tag '#{tag.name}' is not retrievable through Lexaur" unless found&.include?(tag.id)
      end
    end
    self.new(input: string, token: token, lexaur: lexaur).go report_on: true
  end

  # Return an array of CSS selectors to be applied to parsing content from the given site.
  # These are used to check completion when accessing a dynamic site, and all must
  # be matched before giving up.
  def self.selectors_for site
    return [] unless site
    grammar = Parser.finalized_grammar mods_plus: site.grammar_mods
    # Require content for title, ingredient list and ingredient line
    selectors = grammar.collect do |key, value|
      if value.is_a?(Hash) && [:rp_title, :rp_inglist, :rp_ingline].include?(key)
        value.slice(:in_css_match, :at_css_match, :after_css_match).values.compact.first
      end
    end
    selectors.compact
  end

  # Apply the parser to a NokoScanner
  def parser
    @parser ||= Parser.new scanner, @lexaur, @grammar_mods
    puts "Activating parser with report #{@report_on ? 'on' : 'off'}"
    @parser.report_on = @report_on # Optionally turn on reporting
    @parser
  end

  def parser=p
    @parsed = nil if p != @parser  # New parser invalidates :parsed
    @parser = p
  end

  def lexaur=l
    self.parser = nil if l.nil? || l != @lexaur
    @lexaur = l
  end

  def grammar_mods=gm
    self.parser = nil if gm.nil? || gm != @grammar_mods # Start all over again
    @grammar_mods = gm
  end

  def input
    @input || @entity.content
  end
  
  # Setting @input invalidates @scanner
  def input=ct
    @scanner = nil if ct.nil? || ct != @input
    @input = ct
  end

  def entity=e
    self.grammar_mods = e&.site&.grammar_mods
    self.input = nil if e.nil? || e != @entity # Assert grammar_mods, if any
    @entity = e
  end

  # What is the default top-level ask for the entity?
  def token
    @token ||=
        case @entity
        when Recipe
          :rp_recipe
        when RecipePage
          :rp_recipelist
        else
          err_msg = "Illegal attempt to parse #{@entity&.class || 'without associated'} object"
          @entity.errors.add :url, err_msg if @entity
          raise err_msg
        end
  end

  def token=tk
    @parsed = nil if tk != @token || tk.nil?
    @token = tk
  end

  # The NokoScanner is derived from the designated input or, if no input, the entity's content
  # per NokoScanner initialization, @input may be any of a string, scanner, tokens or Nokogiri document
  def scanner
    @scanner ||=
        case @input
        when NokoScanner, StrScanner
          @input
        when nil # Fall back on the entity's input
          NokoScanner.new @entity&.content
        else # Let NokoScanner sort it out
          NokoScanner.new @input
        end
  end

  def content
    nkdoc&.to_s
  end

  def self.benchmark_formatted bm = @match_benchmarks
    return {} unless (bm && vals = bm[:cache_on])

    vals_on = vals.slice(:utime, :stime, :total, :real).values
    strs = vals_on.collect { |val| "%3.3f" % val }
    str_on = ("Cache On:  %9s + %9s = %9s (real %s); " % strs) +
        " | tries: %4d, hits: %4d, misses: %4d" % [vals[:tries], vals[:hits], vals[:misses]]

    vals = bm[:cache_off]

    vals_off = vals.slice(:utime, :stime, :total, :real).values
    strs = vals_off.collect { |val| "%3.3f" % val }
    str_off = ("Cache Off: %9s + %9s = %9s (real %s); " % strs) +
        " | tries: %4d, hits: %4d, misses: %4d" % [vals[:tries], vals[:hits], vals[:misses]]

    strs = vals_on.zip(vals_off).collect { |on, off| "%3.2f" % (100 * (1.0 - on / off)) }
    str_pct = " %% faster: %8s%% + %8s%% = %8s%% (real %8s%%); " % strs
    { on: str_on, off: str_off, net: str_pct }
  end

  # Extract information from an entity (Recipe or RecipePage) or presented input
  # Options:
  # :input -- HTML to be parsed
  # :token -- token denoting what we're seeking (:rp_recipe, :rp_recipe_list, or any other token in the grammar)
  # :annotate -- Once the input is parsed, annotate the results with HTML entities
  def go options = {}
    self.input = options[:input] if options.key?(:input)
    self.token = options[:token] if options.key?(:token)
    @report_on = options[:report_on]

    # There must be EITHER input or an entity specified
    if input.nil? && entity.nil?
      raise "Error in ParserServices#parse: must provide EITHER input or an entity"
    end
    # Likewise, either a token or an entity must be specified
    if token.nil? && entity.nil?
      raise "Error in ParserServices#parse: must provide EITHER a token or an entity"
    end

    parser.cache_init
    # parser.benchmarks_init

    # Recipe parsing includes a Patternista scan of the document and integration of the results
    @parsed = (token == :rp_recipe) ?
                  parse_recipe( annotate: options[:annotate] ) :
                  parser.match( token, stream: scanner, reparse: true)

    # A little sugar: check ingredient line comments for stray ingredient specs
    if @parsed
      @parsed.find(:rp_ing_comment).each do |comment|
        next if comment.result_stream.to_s.blank?
        # Scan the comments from ingredient lines for stray ingspecs
        if (scanned = parser.scan(comment.result_stream)&.keep_if { |sc| sc.token == :rp_ingspec }).present?
          comment.children.concat scanned
        end
      end
      # Now scan failed inglines for an embedded ingspec, and replace the line if successful
      @parsed.find(:rp_inglist).each do |inglist|
        inglist.children.each_index do |ix|
          line = inglist.children[ix]
          next if line.success? || line.result_stream.to_s.blank?
          if (scanned = parser.scan(line.result_stream)&.find { |sc| sc.token == :rp_ingspec })
            children = [scanned]
            comm = line.result_stream.past scanned.result_stream
            children << Seeker.new(comm, token: :rp_comment) if comm.more?
            inglist.children[ix] = Seeker.new line.result_stream, children: children, token: :rp_ingline # line.children.concat scanned
          end
        end
      end
    end

    # Take the benchmark report from the parser when all is said and done
    @match_benchmarks = parser.benchmark_sum @match_benchmarks

    if @parsed&.success?
      @parsed.enclose_all parser: parser if options[:annotate]
      if Rails.env.test?
        # Report the parsing results
        puts "+++++++++ Final parsing result for :#{token}:"
        report_results @parsed
      end
    end
    
    @parsed
  end

  def annotate_selection token, anchor_path, anchor_offset, focus_path, focus_offset
    # Do QA on the parameters
    if anchor_path.present? && focus_path.present? && anchor_offset.to_i && focus_offset.to_i
      newnode = scanner.tokens.enclose_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, rp_elmt_class: token, tag: parser.tag_for_token(token)
      csspath = newnode.css_path
      xpath = Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
      # Test the revised document: it should not change when converted to html and back into Nokogiri
      if Nokogiri::HTML.fragment(nkdoc.to_s).to_s != nkdoc.to_s
        raise "Annotation failed: new doc. changes on cycling through Nokogiri."
      end
      [ nkdoc.to_s, xpath ]
    end
  end

  # Get content from the Nokogiri document by path
  def extract_via_path path
    # Get the target element
    nkdoc.xpath(path.downcase)&.first # Extract the token at that element
  end

  # parse_on_path: assert the grammar on the element denoted by the path, getting the target token from the element
  def parse_on_path path
    elmt = extract_via_path path
    if (tokens = nknode_rp_classes(elmt)).present?
      # For direct Tag terminals, short-circuit the parsing process with a tag lookup
      if tagtype = tokens.map { |token| Parser.tagtype(token) }.compact.first # This token calls for a tag
        # Go directly to tag lookup in the database
        typenum = Tag.typenum tagtype
        tagstr = elmt.text
        if extant = Tag.strmatch(tagstr, tagtype: typenum, matchall: true).first
          elmt['value'] = extant.name
        else # No such tag found
          # We need a decision from the user whether to
          # 1) assert the tag into the database, or
          # 2) identify an existing tag to which it corresponds.
          # To get a ruling, we present a dialog which asks the question, possibly getting a tag to use.
          # If 1), life goes on and the unparsed tag will be asserted when the page is finally accepted
          # If 2), upon choosing a tag, the submission specifies a value that's asserted as above
          # In any event, we let the calling controller handle it
          yield typenum, tagstr if block_given?
        end
      else
        @scanner = scanner.within_css_match elmt # Use a scanner whose window matches the target element
        go token: tokens.first # Do not assert the element as input, b/c that replaces the scanner
        parsed&.enclose_all parser: parser
      end
    end
    nkdoc.to_s
  end

  def do_for *tokens, &block
    return unless @parsed
    glean_tokens(tokens).each do |token|  # For each specified token
      # For each result under that token
      @parsed.find(token).each { |seeker| block.call seeker, token }
    end
  end

  def found_for token, as: nil
    return [] if token.nil? || (seekers = @parsed.find token).empty?
    # Convert the results according to :as specifier
    return seekers unless as
    found = seekers.map do |seeker|
      case as
      when :amountstring
        [seeker.find(:rp_num_or_range).first&.text, seeker.find(:rp_unit_tag).first&.value].compact.join ' '
      when :numrange
        num_or_range = seeker.find(:rp_num_or_range).first.text
        nums = num_or_range.
            split(/-|to/).
            map(&:strip).
            keep_if { |substr| substr.match /^\d*$/ }.
            map &:to_i
        (nums.first)..(nums.last) if nums.present?
      when :timerange
        next unless timestr = seeker.find(:rp_time).first&.text
        secs =
        if timestr.match(/(\d+)\s+(\w+)/)
          num = $1.to_i
          unit = $2
          case unit
          when /minute/
            num * 60
          when /hour/
            num * 3600
          end
        elsif timestr.match /(\d+):(\d+)/
          ($1 * 60 + $2) * 60
        end
        (secs..secs) if secs
      end
    end
    found.compact.uniq
  end

  private

  def report_results *result_seekers
    result_seekers.each do |result_seeker|
      [:rp_title, :rp_ingspec, :rp_author, :rp_prep_time, :rp_cook_time, :rp_total_time, :rp_yields, :rp_serve ].each do |sym|
        to_report = result_seeker.find(sym)
        to_report.unshift result_seeker if result_seeker.token == sym
        to_report.each do |seeker|
          puts seeker.to_s.gsub("\n", '\n')
          if seeker.token == :rp_ingspec
            puts "\t" + seeker.find(:rp_ingredient_tag).map { |ingred| "'#{ingred.value}'"}.join(', ')
          end
        end
      end
    end
    x=2
  end

  # Special handling for recipes: try a straight parse, then a scan to get other attributes.
  # Merge the results into a single Seeker with appropriate children
  def parse_recipe annotate: nil

    # First, use the grammar directly
    @parsed = parser.match :rp_recipe, stream: scanner

    # Natural parsing of the recipe failed, so extract a title and subsequent material,
    # up to the next title, if any
    if !@parsed
      rlist = go options.merge(token: :rp_recipelist) # Parse the same content for a recipe list
      return @parsed = Seeker.failed(scanner, token: :rp_recipe) unless (rlist&.success? && rp = rlist.find(:rp_recipe).first)
      @parsed = parser.match(:rp_recipe, stream: rp.result_stream)&.if_succeeded || rp
    end
    if Rails.env.test?
      # Report the parsing results
      puts "+++++++++ Standard parsing result for :rp_recipe:"
      report_results @parsed
    end

    # Handle the special case of seekers whose children all have the same token by promoting the children
    # in place of the parent.
    @parsed.traverse(depth_first: true) do |seeker|
      to_delete = []
      seeker.children.sort_by! &:pos # Regularize the order so grandchildren are properly inserted
      seeker.children.each_index { |child_ix|
        child = seeker.children[child_ix]
        case child.token
        when :rp_inglist
          to_keep = child.children.count { |grandchild| grandchild.success? } > 1
          child.children = [] unless to_keep # Without the enclosing inglist, delete all children
        when :rp_instructions
          to_keep = child.text.present?
        when :rp_recipe_section
          # Keep a recipe section iff it has valid ingredients
          to_keep = child.traverse { |descendant| break true if descendant.token == :rp_ingline }
          # valid_ingredients = child.children.any? { |grandchild| [:rp_inglist, :rp_ingline].include? grandchild.token }
          # valid_instructions = child.children.any? { |grandchild| grandchild.token == :rp_instructions }
          # to_keep = valid_ingredients && valid_instructions
          # child.children = [] unless valid_ingredients # Without the enclosing inglist, delete all children
        else
          next unless child.children.present? && child.children.all? { |grandchild| grandchild.token == child.token }
          to_keep = false
        end
        to_delete << child_ix unless to_keep
      }
      while child_ix = to_delete.pop do
        child = seeker.children.delete_at child_ix
        seeker.insert *child.children
      end
    end
    @parsed.children.sort_by! &:pos

    # scanned_seekers = group parser.scan(@parsed.find(:rp_recipe).first&.result_stream || scanner), @parsed.find(:rp_inglist)
    # Now scan the remainder of the recipe--excepting already-found title and ingredient list(s)--for triggered patterns.
    # NB we only scan the first recipe found.
    recipe_seeker = @parsed.find(:rp_recipe).first
    scanned_seekers, pred = [], nil
    parsed_seekers = (recipe_seeker.find(:rp_title) + recipe_seeker.find(:rp_inglist) + recipe_seeker.find(:rp_instructions)).sort_by &:pos
    parsed_seekers.each do |parsed_seeker|
      scanned_seekers += parser.scan(@parsed.result_stream.between pred&.result_stream, parsed_seeker.result_stream)
      # scanned_seekers << parsed_seeker
      pred = parsed_seeker
    end
    scanned_seekers += parser.scan(@parsed.result_stream.between pred, nil)

    # Group results identified as above, e.g., assemble lines into lists
    scanned_seekers = group scanned_seekers, @parsed.find(:rp_inglist)
    if Rails.env.test?
      # Report the parsing results
      puts "+++++++++ Scanned parsing result for :rp_recipe:"
      report_results *scanned_seekers
    end

    # Now to reconcile the seekers extracted via scanning with the parsed result:
    # -- any overlapping ingredient lists are merged
    # Insert each of scanned_seekers by position,
    # clipping the items before and after to its bounds
    scanned_seekers.each do |scanned_seeker_to_insert|
      # Forestall redundancy by rejecting any scanned elements that match existing children
      # in token and range.
      scanned_range = scanned_seeker_to_insert.range
      next if @parsed.find(scanned_seeker_to_insert.token).map(&:range).any? { |parsed_range|
        parsed_range.include?(scanned_range) || scanned_range.include?(parsed_range)
      }
      # Split any :rp_instructions child that encompasses the element
      case scanned_seeker_to_insert.token
      when :rp_parenthetical
        next
      when :rp_inglist
        # Find an overlapping ingredient list to merge with
        extant_il = @parsed.
            find(:rp_inglist).
            find { |il| il.range.overlaps? scanned_seeker_to_insert.range }
        if extant_il
          # Merge the overlapping lists by merging all of scanned_seeker_to_insert's children into extant_il
          scanned_seeker_to_insert.children.each { |child| extant_il.insert child }
          next
        else
          scanned_seeker_to_insert = Seeker.new scanner, children: [ scanned_seeker_to_insert ], token: :rp_inglist
        end
      when :rp_ingline
        # Find an overlapping or adjacent ingredient list to move into.
        # If none, create one and insert it
      end

      parsed_parent, after = @parsed, nil # The parent that will receive the scanned seeker
      # Look for any :rp_instructions result that encloses the scanned seeker, and split it as necessary
      @parsed.traverse do |parent|
        if child_ix = parent.children.find_index { |child| child.token == :rp_instructions && child.range.include?(scanned_range.begin) }
          instructions = parent.children[child_ix]
          parsed_parent = parent # Mark this for later modification
          parsed_parent.children.sort_by &:pos
          # Clear any elements found inside an :rp_instructions section by splitting the latter
          if instructions.text(instructions.pos...scanned_range.begin).blank?
            # No text before the inserted node => reposition the instructions afterward
            instructions.pos = scanned_range.end
          elsif instructions.text(scanned_range.end...instructions.bound).blank?
            instructions.bound = scanned_range.begin
          else
            after = instructions.clone
            instructions.bound, after.pos = scanned_range.begin, scanned_range.end
          end
        end
      end
      insert_before = (binsearch(parsed_parent.children, scanned_range.begin, &:pos) || -1) + 1
      parsed_parent.children.insert insert_before, after if after
      parsed_parent.children.insert insert_before, scanned_seeker_to_insert
    end

    # Now a beauty pass: examine the space between each :ingspec found for stray material
    @parsed.find(:rp_inglist).each do |inglist|
      # Collect ingredient lines from the ingredient list, plus ingredient specs that aren't in a line
      inglines = inglist.find(:rp_ingline)
      inspecs = (inglist.find(:rp_ingspec) -
          inglines.collect { |ingline| ingline.find(:rp_ingspec) }.flatten +
          inglines).sort_by(&:pos)
      if inspecs.empty?
        # Trivial reject of parsed ingredient lists that don't have a single ingredient spec
        @parsed.delete inglist, recur: true
        next
      end
      il_stream = inglist.result_stream
      intervening = il_stream.between nil, inspecs.first&.result_stream
      outspecs = ingspecs_in intervening
      inspecs.each_index do |ix|
        child, succ = inspecs[ix..(ix + 1)]
        outspecs << child
        # Scan the material from the end of child to the beginning of succ for other ingspecs
        intervening = il_stream.between child.result_stream, succ&.result_stream
        outspecs += ingspecs_in intervening
      end
      # Now we have a definitive, sorted collection of ingredient specs in the list.
      # Build them into ingredient lines and set the list's children to those.
      outlines = []
      outspecs.each_index do |ix|
        child, succ = outspecs[ix..(ix + 1)]
        intervening = il_stream.between child.result_stream, succ&.result_stream
        if intervening.length > 0
          comm = Seeker.new(intervening, token: :rp_comment)
          # If child is a line, create/extend its comment with the intervening content
          # If the child is an ingspec, create a line with the intervening content as comment
          case child.token
          when :rp_ingline
            # Replace the line's comment with intervening and extend the line
            if ix = child.children.find_index { |grandchild| grandchild.token == :rp_comment }
              child.children[ix] = comm
            else
              child.children << comm
            end
            child.bound = comm.bound
          when :rp_ingspec
            child = Seeker.new inglist.stream, children: [child, comm], token: :rp_ingline
          end
        end
        outlines << child
      end
      inglist.children = outlines
    end

    # Finally, intersperse :rp_instructions between the ingredient lists
    instrs = []
    @parsed.children.each_index do |child_ix|
      if (child_il = @parsed.children[child_ix]).token == :rp_inglist
        next_child_il = @parsed.children[child_ix+1] # ..-1].find { |subsq| subsq.token == :rp_inglist }
        intervening = @parsed.result_stream.between child_il.result_stream, next_child_il&.result_stream
        instrs << Seeker.new(intervening, token: :rp_instructions) if intervening.more?
      end
    end
    @parsed.insert *instrs

    @parsed&.success?
  end

  def ingspecs_in stream
    streams = []
    while stream.more? && (spec = parser.seek stream, :rp_parenthetical )
      streams << (stream.except spec.head_stream)
      stream = stream.past spec.result_stream
    end
    streams << stream
    results = []
    streams.each do |stream|
      while stream.more? &&
          (spec = parser.seek(stream, :rp_ingspec)) do
        results << spec if spec.find(:rp_amt).present? || spec.find(:rp_presteps).present?
        stream = stream.except spec.stream
      end
    end
    results
  end

  # Gather a set of seekers under larger headers, e.g. gather ingredients into an ingredient list
  def group seekers, extant_ils
    # Search one or more seekers for a token, returning found items across them all, or the results of calling a block
    def find_for *args, &block
      token = args.shift if args.first.is_a?(Symbol)
      seekers = token ? args.collect { |seeker| seeker.find(token) }.flatten(1) : args
      block_given? ?
          seekers.collect { |seeker| block.call seeker }.compact :
          seekers
    end

    # Sort the seekers into ingredient lines and specs
    # Any ingredient lists that were scanned out separately are preserved,
    # and seekers that turned up in the scan are ignored if they're contained in the list.
    extant_ils.first&.open_range
    extant_ranges = find_for(*extant_ils) { |il| il.open_range }
    seekers.delete_if do |seeker|
      [:rp_inglist, :rp_ingline, :rp_ingspec].include?(seeker.token) &&
          extant_ranges.any? { |extant_range| extant_range.include? seeker.range }
    end
    # Separate out the ingredient lists from the remaining scanned seekers
    inglists = seekers.find_all { |seeker| seeker.token == :rp_inglist }
    seekers -= inglists
    # ...and finally, extract ingspecs that are embedded in scanned seekers
    ingspecs = find_for(:rp_ingspec, *seekers) { |ingspec| ingspec unless extant_ranges.any? { |extant_range| extant_range.include? ingspec.range }}
    # First, remove children of the scanned inglist(s) that are redundant wrt extant ingredient lists.
    # This means 1) is the child w/in the bounds of the extant list, or 2) its tag already appears there
    extant_ingred_ids = find_for(:rp_ingredient_tag, *extant_ils) { |tag| tag.tagdata[:id] }.uniq
    inglists.keep_if do |inglist|
      # Remove redundant children, i.e., those whose tag(s) already appear on an extant ingredient list
      inglist.children.delete_if { |ingchild|
        extant_ranges.any? { |extant_range| extant_range.include? ingchild.range } ||
            (find_for(:rp_ingredient_tag, ingchild) { |tag| tag.tagdata[:id] }.flatten - extant_ingred_ids).empty?
      }
      #
      if inglist.children.count > 1
        inglist.pos = inglist.children.first.pos
        inglist.bound = inglist.children.last.bound
      end
    end

    return (seekers + inglists) unless ingspecs.present? || inglists.present?

    extant_il_ancestors = extant_ils.
        collect { |extant_il|
          extant_il.result_stream.text_element.ancestors.to_a
        }.
        flatten.
        uniq

    # We aggregate a collection of ingredient lines that haven't been reconciled with an extant ingredient list into lists as follows:
    # The idea is to nominate one or more ancestors of the ingredient specs as an ingredient list(s)
    # * Each node in the Nokogiri ancestry of each ingspec gets a point for being on the path to that node
    # * We derive a "branching factor" for each such ancestor: the count of its children which lead to an ingline
    # * i.e., if an ancestor has five children which each lead to ingspecs, its branching factor is five,
    # * but its parent's branching factor is only one
    # Thus, the most likely candidates to be an ingredient-list node are those with the highest b.f.

    # A BinCount is a hash where the keys are Nokogiri nodes and the values are the count for that node.
    bc = BinCount.new
    # Initialize the bincount by looping across each ingline and incrementing all of its ancestors
    ingspecs.each do |seeker|
      bc.increment *(seeker.head_stream.text_element.ancestors.to_a - extant_il_ancestors)
    end
    # Here's the tricky bit: get the b.f. for each node by DECREMENTING the count of its parent
    # by N-1, where N is its initial count, i.e., the number of its children leading to an ingnode.
    # The following loop works only because, once a node is decremented, N-1 becomes 0, so it
    # doesn't matter how many times or in what order the nodes in the tree are visited.
    nkdoc.traverse do |node|
      if (adj = bc[node] - 1) > 0
        node.ancestors.each { |anc|
          break if extant_il_ancestors.include?(anc)
          bc[anc] -= adj }
      end
    end
    # Remove the root (the document fragment) from consideration
    bc.delete nkdoc
    # inglists = []
    while (max = bc.max) && (max.count > 2) do
      puts "#{max.count} at '#{max.object.to_s.truncate 200}'"
      # Declare a result for the found collection, including all text elements under it
      range = scanner.token_range_for_subtree max.object
      children = ingspecs.select { |line| range.include?(line.pos) && range.include?(line.bound) }
      inglines = []
      children.each_index { |ix|
        child, succ = children[ix..(ix + 1)]
        # Scan the material from the end of child to the beginning of succ for other ingspecs
        intervening = succ ? (child.tail_stream.except succ.head_stream) : child.tail_stream.within(range)
        next_spec = parser.seek intervening, :rp_ingspec
        while intervening.more? && next_spec do
          noise = intervening.except(next_spec.stream)
          comm = noise.to_s.strip.present? ? Seeker.new(noise, token: :ing_comment) : nil
          newline = Seeker.new(token: :rp_ingline, children: [child, comm].compact)
          inglines << newline
          child = next_spec
          intervening = succ ? (child.tail_stream.except succ.head_stream) : child.tail_stream.within(range)
          while intervening.peek == "\n" do
            intervening.first
          end
          next_spec = parser.seek intervening, :rp_ingspec
        end
        extracted = parser.match(:rp_ingline, stream: child.head_stream.except(succ&.head_stream), singular: true) || child
        ps = if comment = extracted.find(:rp_ing_comment).first
               parser.scan comment.head_stream.except(succ&.head_stream)
             end
        inglines << extracted
        while extracted = parser.match(:rp_ingline, stream: extracted.tail_stream.except(succ&.head_stream), singular: true) do
          inglines << extracted
        end
      }
      inglists << Seeker.new(scanner, children: inglines, range: range, token: :rp_inglist)
      # Remove this tree from consideration for higher-level inglists
      max.object.ancestors.each { |anc| bc[anc] -= 1 }
      bc.delete max.object
    end

    inglists + seekers.keep_if { |item| ![:rp_parenthetical, :rp_inglist, :rp_ingline, :rp_ingspec].include? item.token }
  end

  # Given an ingredient list with a collection of items, infer an
  # enclosing HTML/CSS context, returning a CSS selector for it
  def ingline_selector inglist
    # The inglist denotes the lowest common node between the elements
    # For each child, we examine each parent of the leading text element for commonality
    teds = inglist.children.map(&:head_stream).map &:text_elmt_data
    # We assume that the nokogiri node associated with the inglist is the common ancestor of two children
    inglist_nknode = (teds.first.ancestors.to_a & teds.last.ancestors.to_a).first
    descendant_ix = -(inglist_nknode.ancestors.count+2) # This indexes the first ancestor of a text element that is a child of the inglist
    first_descendants = teds.map { |ted| ted.text_element.ancestors[descendant_ix] }
    survivors = nil
    first_descendants.each do |child_nknode|
      this = { tag: child_nknode.name, classes: child_nknode['class']&.split || [] }
      if survivors
        survivors.delete :tag if this[:tag] != survivors[:tag]
        survivors[:classes] &= this[:classes]
      else
        survivors = this
      end
    end
    classes = survivors[:classes].join '.'
    selector = "#{survivors[:tag]}#{('.'+classes) if classes.present?}"
    selector
  end

  def glean_tokens token_list
    exceptions =
        if exceptions_index = token_list.index { |v| v.is_a? Hash } # returns index if block is true
          [token_list.delete_at(exceptions_index)[:except]].flatten # ...allowing single token or array
        else
          []
        end
    token_list = @parser.tokens if token_list.empty?
    token_list - exceptions
  end

end
