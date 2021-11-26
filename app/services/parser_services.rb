require 'recipe.rb'
require 'scraping/parser.rb'
require 'recipe_page.rb'

class ParserServices
  attr_reader :parsed, # Trees of seeker results resulting from parsing and scanning, respectively
              :grammar_mods, # Modifications to be used on the parser beforehand
              :input,
              :match_benchmarks, # Retains the benchmarks for the last parse
              :nokoscan # The scanner associated with the current input

  delegate :nkdoc, to: :nokoscan
  delegate :'success?', :find, :hard_fail?, :find_value, :value_for, :xbounds, to: :parsed

  def initialize entity: nil, token: nil, input: nil, lexaur: nil, grammar_mods: nil
    self.entity = entity # Object (ie., Recipe or RecipePage) to be parsed
    self.token = token
    self.input = input
    self.lexaur = lexaur
    self.grammar_mods = grammar_mods
  end

=begin
Here is where all dependencies in the parser are expressed: dependent variables are cleared
when the entities on which they depend are expressed.
The dependencies are as follows:
@parsed, @scanned
  @token
  @parser
    @input
      @entity
    @grammar_mods
      @entity
    @lexaur
...therefore, when any of them are set, their dependents must be nulled out (recursively)
=end

  # Apply the parser to a NokoScanner
  def parser
    @parser ||= Parser.new nokoscan, @lexaur, @grammar_mods
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
  
  # Setting @input invalidates @nokoscan
  def input=ct
    @nokoscan = nil if ct.nil? || ct != @input
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
  def nokoscan
    @nokoscan ||=
        case @input
        when NokoScanner
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

=begin
  # Divide a line by commas and 'and', parsing the sections into instances of the token
  def chunk_line token: :rp_ingline
    nks = nokoscan # Save for later
    results = nks.split(',').collect { |chunk| parse input: chunk, token: token }
    # If the last clause contains multiple 'and' tokens, split across each one in turn
    turns = results.last.head_stream.split('and').delete_if &(:blank?)
    pairs = []
    turns[0...-1].each_index do |i|
      pairs.push [ parse(input: turns[0].encompass(turns[i]), token: token),
                   parse(input: turns[(i+1)].encompass(turns[-1]), token: token) ]
    end
    if pairs.first&.all? &:'success?'
      results.pop
      results += pairs.first
    end
    self.input = nks
    @parsed = Seeker.new nks, results.last.tail_stream, token, results
  end
=end

  # Extract information from an entity (Recipe or RecipePage) or presented input
  # Options:
  # :input -- HTML to be parsed
  # :token -- token denoting what we're seeking (:rp_recipe, :rp_recipe_list, or any other token in the grammar)
  # :as_stream -- flag to parser#match to parse the input as though CSS selectors and line constraints have already been matched
  # :annotate -- Once the input is parsed, annotate the results with HTML entities
  def go options = {}
    self.input = options[:input] if options.key?(:input)
    self.token = options[:token] if options.key?(:token)

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
                  parse_recipe( options.slice(:as_stream, :annotate)) :
                  parser.match( token, stream: nokoscan, as_stream: options.delete(:as_stream))

    # A little sugar: check ingredient line comments for stray ingredient specs
    @parsed.find(:rp_ing_comment).each do |comment|
      next if comment.result_stream.to_s.blank?
      # Scan the comments from ingredient lines for stray ingspecs
      if (scanned = parser.scan(comment.result_stream)&.keep_if { |sc| sc.token == :rp_ingspec }).present?
        comment.children.concat scanned
      end
    end if @parsed

    # Take the benchmark report from the parser when all is said and done
    @match_benchmarks = parser.benchmark_sum @match_benchmarks

    if @parsed&.success?
      @parsed.enclose_all parser: parser if options[:annotate]
      if Rails.env.test?
        # Report the parsing results
        puts "+++++++++ Final parsing result for :#{token}:"
        report_results @parsed
      end
      @parsed
    end
  end

  def annotate_selection token, anchor_path, anchor_offset, focus_path, focus_offset
    # Do QA on the parameters
    if anchor_path.present? && focus_path.present? && anchor_offset.to_i && focus_offset.to_i
      newnode = nokoscan.tokens.enclose_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, rp_elmt_class: token, tag: parser.tag_for_token(token)
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
    #@nkdoc = elmt.ancestors.last
    # nokoscan = NokoScanner.new elmt
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
        go input: elmt, token: tokens.first
        parsed.enclose_all parser: parser
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
        [seeker.find(:rp_num_or_range).first&.to_s, seeker.find(:rp_unit_tag).first&.value].compact.join ' '
      when :numrange
        num_or_range = seeker.find(:rp_num_or_range).first.to_s
        nums = num_or_range.
            split(/-|to/).
            map(&:strip).
            keep_if { |substr| substr.match /^\d*$/ }.
            map &:to_i
        (nums.first)..(nums.last) if nums.present?
      when :timerange
        next unless timestr = seeker.find(:rp_time).first&.to_s
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
  def parse_recipe scanner=nokoscan, options={}
    scanner, options = nokoscan, scanner if scanner.is_a?(Hash)

    @parsed = parser.match :rp_recipe, stream: scanner, as_stream: options.delete(:as_stream)

    # Natural parsing of the recipe failed, so extract a title and subsequent material,
    # up to the next title, if any
    if !@parsed
      rlist = go options.merge(token: :rp_recipelist) # Parse the same content for a recipe list
      return @parsed = Seeker.failed(nokoscan, token: :rp_recipe) unless (rlist&.success? && rp = rlist.find(:rp_recipe).first)
      @parsed = parser.match(:rp_recipe, stream: rp.result_stream, as_stream: options.delete(:as_stream))&.if_succeeded || rp
    end
    if Rails.env.test?
      # Report the parsing results
      puts "+++++++++ Standard parsing result for :rp_recipe:"
      report_results @parsed
    end

    # Scan the input for triggered patterns, and group ingspecs thus found into lines
    scanned_seekers = group parser.scan(scanner), @parsed.find(:rp_inglist)
    if Rails.env.test?
      # Report the parsing results
      puts "+++++++++ Scanned parsing result for :rp_recipe:"
      report_results *scanned_seekers
    end

    children = @parsed.children
    # Whether parsed directly or as above, the recipe will have a title followed by instructions
    children.sort_by &:pos # Ensure that the elements are sorted by position

    # Insert each of scanned_seekers by position,
    # clipping the items before and after to its bounds
    scanned_seekers.each do |to_insert|
      # Split any :rp_instructions child that encompasses the element
      case to_insert.token
      when :rp_parenthetical
        next
      when :rp_inglist
        # Find an overlapping ingredient list to merge with
        extant_il = @parsed.
            find(:rp_inglist).
            find { |il| il.range.overlaps? to_insert.range }
        if extant_il
          # Merge the overlapping lists by merging all of to_insert's children into extant_il
          to_insert.children.each { |child| extant_il.insert child }
          next
        else
          to_insert = Seeker.new scanner, children: [ to_insert ], token: :rp_inglist
        end
      when :rp_ingline
        # Find an overlapping or adjacent ingredient list to move into.
        # If none, create one and insert it
      end
      after = nil
      children.find_index { |child|
        if child.token == :rp_instructions && child.range.include?(to_insert.pos)
          if child.text(child.pos...to_insert.pos).blank?
            # No text before the inserted node => reposition the child afterward
            child.pos = to_insert.bound
          elsif child.text(to_insert.bound...child.bound).blank?
            child.bound = to_insert.pos
          else
            after = child.clone
            child.bound, after.pos = to_insert.pos, to_insert.bound
          end
        end
      }
      # Forestall redundancy by rejecting any scanned elements that match existing children
      # in token and range
      next if children.any? { |child|
        child.token == to_insert.token &&
            (child.range.include?(to_insert.range) || to_insert.range.include?(child.range))
      }
      insert_before = (binsearch(children, to_insert.pos, &:pos) || -1) + 1
      children.insert insert_before, after if after
      children.insert insert_before, to_insert
    end

    @parsed&.success?
  end

  # Gather a set of seekers under larger headers, e.g. gather ingredients into an ingredient list
  def group seekers, extant_ils
    # Sort the seekers into ingredient lines and specs
    # Any ingredient lists that were scanned out separately are preserved
    seekers.delete_if do |seeker|
      [:rp_inglist, :rp_ingline, :rp_ingspec].include?(seeker.token) &&
          extant_ils.any? { |extant_il| extant_il.range.include? seeker.range }
    end
    inglists = seekers.find_all { |seeker| seeker.token == :rp_inglist }
    seekers -= inglists
    ingspecs = seekers.collect { |seeker| seeker.find :rp_ingspec }.
        flatten.
        delete_if { |ingspec| extant_ils.any? { |extant_il| extant_il.range.include? ingspec.range } }
    return (seekers+inglists) unless ingspecs.present?

    # We aggregate a collection of ingredient lines as follows:
    # The idea is to
    # * Each node in the Nokogiri ancestry of each ingline gets a point for being on the path to that node
    # * We derive a "branching factor" for each such ancestor: the count of its children which lead to an ingline
    # * i.e., if an ancestor has five children which each lead to ingspecs, its branching factor is five,
    # * but its parent's branching factor is only one
    # Thus, the most likely candidates to be an ingredient-list node are those with the highest b.f.

    # A BinCount is a hash where the keys are Nokogiri nodes and the values are the count for that node.
    bc = BinCount.new
    # Initialize the bincount by looping across each ingline and incrementing all of its ancestors
    ingspecs.each do |seeker|
      bc.increment *seeker.head_stream.text_element.ancestors.to_a
    end
    # Here's the tricky bit: get the b.f. for each node by DECREMENTING the count of its parent
    # by N-1, where N is its initial count, i.e., the number of its children leading to an ingnode.
    # The following loop works only because, once a node is decremented, N-1 becomes 0, so it
    # doesn't matter how many times or in what order the nodes in the tree are visited.
    nkdoc.traverse do |node|
      if (adj = bc[node] - 1 ) > 0
        node.ancestors.each { |anc| bc[anc] -= adj }
      end
    end
    # Remove the root (the document fragment) from consideration
    bc.delete nkdoc
    # inglists = []
    while (max = bc.max) && (max.count > 2) do
      puts "#{max.count} at '#{max.object.to_s.truncate 200}'"
      # Declare a result for the found collection, including all text elements under it
      range = nokoscan.token_range_for_subtree max.object
      children = ingspecs.select { |line| range.include?(line.pos) && range.include?(line.bound) }
      inglines = []
      children.each_index { |ix|
        child, succ = children[ix..(ix+1)]
        # Scan the material from the end of child to the beginning of succ for other ingspecs
        intervening = succ ? (child.tail_stream.except succ.head_stream) : child.tail_stream.within(range)
        next_spec = parser.seek intervening, :rp_ingspec
        while intervening.to_s.present? && next_spec do
          noise = intervening.except(next_spec.stream)
          comm = noise.to_s.strip.present? ? Seeker.new(noise, token: :ing_comment) : nil
          newline = Seeker.new(token: :rp_ingline, children: [child, comm].compact )
          inglines << newline
          child = next_spec
          intervening = succ ? (child.tail_stream.except succ.head_stream) : child.tail_stream.within(range)
          while intervening.peek == "\n" do
            intervening.first
          end
          next_spec = parser.seek intervening, :rp_ingspec
          # next_spec = parser.match :rp_ingspec, stream: intervening, as_stream: true, singular: true
        end
        extracted = parser.match(:rp_ingline, stream: child.head_stream.except(succ&.head_stream), as_stream: true, singular: true ) || child
        ps = if comment = extracted.find(:rp_ing_comment).first
          parser.scan comment.head_stream.except(succ&.head_stream)
        end
        inglines << extracted
        while extracted = parser.match(:rp_ingline, stream: extracted.tail_stream.except(succ&.head_stream), as_stream: true, singular: true ) do
          inglines << extracted
        end
      }
      inglists << Seeker.new(nokoscan, children: inglines, range: range, token: :rp_inglist)
      # Remove this tree from consideration for higher-level inglists
      max.object.ancestors.each { |anc| bc[anc] -= 1 }
      bc.delete max.object
    end

    inglists + seekers.keep_if { |item| ![:rp_parenthetical, :rp_inglist, :rp_ingline, :rp_ingspec ].include? item.token}
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
