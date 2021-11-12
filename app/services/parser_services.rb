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
  # :in_place -- flag to parser#match to parse the input as though CSS selectors and line constraints have already been matched
  # :annotate -- Once the input is parsed, annotate the results with HTML entities
  def go options = {}
    self.input = options[:input] if options.key?(:input)
    self.token = options[:token] if options.key?(:token)
    seeking = options[:seeking] || [:rp_title, :rp_inglist, :rp_instructions]
    # There must be EITHER input or an entity specified
    if input.nil? && entity.nil?
      raise "Error in ParserServices#parse: must provide EITHER input or an entity"
    end
    # Likewise, either a token or an entity must be specified
    if token.nil? && entity.nil?
      raise "Error in ParserServices#parse: must provide EITHER a token or an entity"
    end

    # parser.cache_init
    # parser.benchmarks_init
    parsed, scanned_seekers =
    case token
    when :rp_recipe
      # Place our fate in the hands of #parse_recipe
      [parse_recipe(options.slice(:in_place, :annotate)), []]
    when :rp_recipelist
      # First break up the document into recipes, then parse each one separately
      @parsed = parser.match :rp_recipelist, stream: nokoscan, in_place: options.delete(:in_place)
      @parsed.traverse do |node|
        node.children.map! { |child|
          (child.token == :rp_recipe && parse_recipe(nokoscan.slice(child.range), options)&.if_succeeded) || child
        }
      end
    else
      annotate = options.delete :annotate
      parsed = parser.match token, stream: nokoscan, in_place: options.delete(:in_place)
      # Perform the scan only if sought elements aren't found in the parse
      [parsed, group(parser.scan)] # if seeking.any? { |token| !parsed&.find(token).first }
    end
    # Take the benchmark report from the parser when all is said and done
    @match_benchmarks = parser.benchmark_sum @match_benchmarks

    if parsed
      # Now we need to reconcile parsed results with scanned.
      ils = parsed.find(:rp_inglist)
      scanned_seekers.keep_if do |scanned_seeker|
        # In this step, we eliminate scanned elements that have a parsed equivalent
        case scanned_seeker.token
        when :rp_inglist
          selector = ingline_selector scanned_seeker
          # Special processing for inglists: merge their children into the parsed equivalent, as possible
          # First, adjust the parsed ingredient-list boundaries to the scanned_seeker item
          ils.each do |inglist|
            if scanned_seeker.token_range.include? inglist.pos
              # Expand the inglist token_range to include the scanned version,
              # but not so far as to encroach on other parsed elements
              inglist.encompass_position (ils.filter { |il| il.pos < inglist.pos }.map(&:bound) << scanned_seeker.pos).max
            end
            if scanned_seeker.token_range.include? inglist.bound
              inglist.encompass_position (ils.filter { |il| il.bound > inglist.bound }.map(&:pos) << scanned_seeker.bound).min
            end
          end
          true
        when :rp_parenthetical
        else
          !parsed.find(scanned_seeker.token).any? { |parsed| parsed.matches? scanned_seeker }
        end
      end

      # Now scanned_seekers is a list of elements that still need to be included in the parse tree
      scanned_seekers.each do |scanned_seeker|
        if scanned_seeker.token == :rp_inglist
          scanned_seeker.children.keep_if { |ingline| !ils.any? { |inglist| inglist.insert ingline } }
          next if scanned_seeker.children.empty?
        end
        parsed.insert scanned_seeker
      end
    else # No parsed content: just use the scanned results by enclosing them
      parsed =
          case scanned_seekers.count
          when 0
            Seeker.failed @nokoscan, token: token
          when 1
            scanned_seekers.first
          else
            Seeker.new @nokoscan, children: scanned_seekers, token: token
          end
    end

    parsed.enclose_all parser: parser if parsed&.success? && annotate

    (@parsed = parsed)&.success?
  end

  # Special handling for recipes: try a straight parse, then a scan to get other attributes.
  # Merge the results into a single Seeker with appropriate children
  def parse_recipe options={}

    @parsed = parser.match token, stream: nokoscan, in_place: options.delete(:in_place)

    # Perform the scan only if sought elements aren't found in the parse
    scanned_seekers = group parser.scan # if seeking.any? { |token| !@parsed&.find(token).first }

    # Take the benchmark report from the parser when all is said and done
    @match_benchmarks = parser.benchmark_sum @match_benchmarks

    # Natural parsing of the recipe failed, so extract a title and subsequent material,
    # up to the next title, if any
    if !@parsed
      # Extract a title
      rcps = parser.match :rp_recipelist, stream: nokoscan
      return nil unless @parsed = rcps&.children&.first

      @parsed.children.last.token = :rp_instructions
    end
    children = @parsed.children
    # Whether parsed directly or as above, the recipe will have a title followed by instructions
    children.sort_by &:pos # Ensure that the elements are sorted by position

    # Take each scanned_seekers element and insert it by position,
    # clipping the items before and after to its bounds
    scanned_seekers.each do |to_insert|
      # Split any :rp_instructions child that encompasses the element
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
      insert_before = (binsearch(children, to_insert.pos, &:pos) || 0) + 1
      children.insert insert_before, after if after
      children.insert insert_before, to_insert
    end

    @parsed&.success?
  end

  def content
    nkdoc&.to_s
  end

  # Gather a set of seekers under larger headers, e.g. gather ingredients into an ingredient list
  def group seekers
    inglines = []
    others = []
    # Sort the seekers into ingredient lines and others
    seekers.each do |seeker|
      if [:rp_ingspec, :rp_ingline].include? seeker.token
        inglines << seeker
      else
        others << seeker
      end
    end
    return seekers unless inglines.present?

    # We aggregate a collection of ingredient lines as follows:
    # The idea is to
    # * Each node in the Nokogiri ancestry of each ingline gets a point for being on the path to that node
    # * We derive a "branching factor" for each such ancestor: the count of its children which lead to an ingline
    # * i.e., if an ancestor has five children which each lead to inglines, its branching factor is five,
    # * but its parent's branching factor is only one
    # Thus, the most likely candidates to be an ingredient-list node are those with the highest b.f.

    # A BinCount is a hash where the keys are Nokogiri nodes and the values are the count for that node.
    bc = BinCount.new
    # Initialize the bincount by looping across each ingline and incrementing all of its ancestors
    inglines.each { |seeker| bc.increment *seeker.head_stream.text_element.ancestors.to_a }
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
    inglists = []
    while (max = bc.max) && (max.count > 2) do
      puts "#{max.count} at '#{max.object.to_s.truncate 200}'"
      # Declare a result for the found collection, including all text elements under it
      range = nokoscan.token_range_for_subtree max.object
      children = inglines.select { |line| range.include?(line.pos) && range.include?(line.bound) }
      inglists << Seeker.new(nokoscan, children: children, range: range, token: :rp_inglist)
      # Remove this tree from consideration for higher-level inglists
      max.object.ancestors.each { |anc| bc[anc] -= 1 }
      bc.delete max.object
    end

    others + inglists
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
