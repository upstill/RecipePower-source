require 'string_utils.rb'
require 'binsearch.rb'
require 'scraping/text_elmt_data.rb'
require 'scraping/noko_tokens.rb'
require 'scraping/noko_utils.rb'

# If possible, apply the rp_elmt_class to an ancestor of the two text elements
# "possible" means that all text of the ancestor before the first and after the last
# text element is blank.
# We must also take care not to violate the associated grammar hierarchy:
#   we want to tag the highest compatible node
def tag_ancestor_safely node, first_te, last_te, rp_elmt_class:, tag: nil, value: nil, parser_evaluator: nil

  tag = tag&.to_s || 'span'
  rp_elmt_class ||= ''
  tags = tag.split ',' # The tag may specify multiple comma-separated tags

  # The set of nodes to search is the node's ancestors,
  # including the node but excluding the top-level fragment,
  # which have no other non-blank text.
  node.
  ancestors.
  to_a[0...-1].
  unshift(node).
  each do |anc|
    return unless nknode_text_before(first_te, within: anc).blank? && nknode_text_after(last_te, within: anc).blank?
    # Disqualify a node that can't be contained under the requisite class
    if (tag.blank? || tags.include?(anc.name)) && (value.nil? || anc['value'].nil?)
      nknode_clear_classification_context anc, rp_elmt_class, parser_evaluator: parser_evaluator
      nknode_apply anc, rp_elmt_class: rp_elmt_class, value: value
      return anc
    #elsif (incompatible_classes = nknode_rp_classes(anc).delete_if { |cl| @parser_evaluator.can_include? rp_elmt_class, cl }).present?
    #  nknode_rp_classes anc, (nknode_rp_classes(anc) - incompatible_classes)
    end
  end
  return nil
end

# Minimize the text enclosed by the two text elements, by ignoring empty text
def tighten_text_elmt_enclosure anchor_elmt, focus_elmt
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first
  while anchor_elmt.to_s.blank? do
    anchor_elmt = nknode_successor_text_elmt common_ancestor, anchor_elmt
  end
  # Back the focus_elmt up as long as it's blank
  while focus_elmt.to_s.blank? do
    focus_elmt = nknode_predecessor_text_elmt common_ancestor, focus_elmt
  end
  return [ anchor_elmt, focus_elmt ]
end

# Brute-force moving all the text enclosed in the tree between anchor_elmt and focus_elmt, inclusive,
# into an enclosure that's a child of their common ancestor--unless there's already an ancestor tagged
# according to spec, or can be so modified.
def assemble_tree_from_nodes anchor_elmt, focus_elmt, rp_elmt_class:, tag: :span, value: nil

  # Ignore blank text outside the range
  anchor_elmt, focus_elmt = tighten_text_elmt_enclosure anchor_elmt, focus_elmt
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first
  anchor_elmt = undivided_ancestor anchor_elmt, :blank_left, common_ancestor
  focus_elmt = undivided_ancestor focus_elmt, :blank_right, common_ancestor

  # If there's an ancestor with no preceding or succeeding text, mark that and return
  if anc = tag_ancestor_safely(common_ancestor, anchor_elmt, focus_elmt, tag: tag, rp_elmt_class: rp_elmt_class, value: value)
    return anc
  end

  # If not provided directly, build the tree.
  # It is to appear under the common ancestor of the anchor and the focus, so
  # it has a very specific placement requirement: <between>
  # where anchor_root and focus_root are now. But either of those could be moved entirely into
  # the new tree.
  # Create a Nokogiri node from the parameters
  throw "Can't #assemble_tree_from_nodes where tag is not a string or a symbol" if !(tag.is_a?(String) || tag.is_a?(Symbol))
  newtree = (Nokogiri::HTML.fragment html_enclosure(tag: tag, rp_elmt_class: rp_elmt_class, value: value)).children[0]
  # We let #node_walk determine the insertion point: successor_node is the node that comes AFTER the new tree
  iterator = DomTraversor.new anchor_elmt, focus_elmt, :enclosed
  iterator.walk do |node|
    newtree.add_child node
  end
  if iterator.successor_node # newtree goes where focus_root was
    iterator.successor_node.previous = newtree
  else # The focus node was the last child, and now it's gone => make newtree be the last child
    common_ancestor.add_child newtree
  end
  # validate_embedding newtree
  return newtree
end

def report_tree label, nokonode, first_te = nil, last_te = nil
  if Rails.env.development?
    puts label
    preface = (inside = first_te.nil?) ? '>>>>>' : 'vvvvv'
    past_it = false
    nokonode.traverse do |node|
      if node.text?
        if node == first_te
          inside = true
          preface = '>>>>> '
        end
        puts "\t#{preface} #{escape_newlines node.to_s}" if inside
        if node == last_te
          inside == false; past_it = true; preface = '^^^^^'
        end
      end
    end
    # puts "#{label}#{escape_newlines nokonode.inner_text}"
  end
  nokonode
end

# Special case: You can't put a <div> inside a <p>, so we may have to split the common ancestor to accommodate
def validate_embedding newtree
  if %w{ div ul li }.include? newtree.name
    # We have to split ancestors up to and including any <p>
    while inappropriate_ancestor = newtree.ancestors.find { |node| node.name == 'p' } do
      # This is a node in newtree's ancestry which is disqualified from containing newtree,
      # directly or indirectly. Without violating text order, we need to move newtree to be a
      # sibling of the offending ancestor.

      parent = newtree.parent
      # If the interfering element has no successor or predecessor in the paragraph, simply hoist it up to be a sibling
      if !newtree.next
        parent.next = newtree
        parent.remove if parent.text.empty?
      elsif !newtree.previous
        parent.previous = newtree
        parent.remove if parent.text.empty?
      else
        # We have to split the paragraph, leaving the new tree between parts
        # first_down is the child of inappropriate_ancestor which is an ancestor of newtree.
        # Of course, it may be newtree itself
        first_down = (newtree.child.ancestors - inappropriate_ancestor.child.ancestors).last
        ix = inappropriate_ancestor.children.find_index { |child| child == first_down }
        inappropriate_ancestor.next = newtree.document.create_element inappropriate_ancestor.name, inappropriate_ancestor.attributes
        inappropriate_ancestor.next.children = inappropriate_ancestor.children[ix..-1]
        inappropriate_ancestor.next = inappropriate_ancestor.next.children.first
        #
        # ix = parent.children.find_index { |child| child == newtree }
        # parent.next = newtree
        # break if ix == parent.children.count # No more work to do if this is the last child of the parent
        # newtree.next = newtree.document.create_element parent.name, parent.attributes
        # newtree.next.children = parent.children[ix..-1]
      end
    end
  end
  newtree
end

def html_enclosure tag: 'div', rp_elmt_class:'', value: nil
  tag ||= 'div'
  valuestr = "value='#{HTMLEntities.new.encode(value)}'" if value.present?
  class_str = 'rp_elmt'
  class_str << ' ' + rp_elmt_class.to_s if rp_elmt_class
  "<#{tag} class='#{class_str}' #{valuestr}></#{tag}>" # For constructing the new node
end

# Define methods that all scanners must implement
class Scanner < Object
  attr_reader :pos, :bound

  # peek: return the token (if ntokens == 1) or tokens (space-separated) in the current read position without advancing
  def peek ntokens = 1
  end

  # first: return the token in the current read position and advance to the position

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first ntokens = 1
    if str = peek(ntokens)
      @pos += ntokens
      @pos = @bound if @pos > @bound
    end
    str
  end

  # Provide a string representing the content of the stream from its current position, terminating at the bound
  def to_s limit = nil, nltr: false, trunc: nil
    peek ((limit || @bound) - @pos)
  end

  alias_method :text, :to_s

  def range
    @pos...@bound
  end

  def length
    @bound - @pos
  end

  # Does the stream have more content?
  def more?
    @pos < @bound
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars = 1
    clone_for pos: [(@pos+nchars), @bound].min
  end

  # Return this scanner, exhausted
  def end
    clone_for pos: @bound
  end

  def all
    clone_for pos: 0
  end

  # Create a scanner that starts where the given scanner (or an Integer position) starts
  def goto scanner_or_position
    clone_for pos: (scanner_or_position.is_a?(Integer) ? scanner_or_position : scanner_or_position.pos)
  end

  # Take a slice of the scanner's range. If a Fixnum is given, return the natural range beginning at that point
  def slice fixnum_or_range
    case fixnum_or_range
    when Integer
      # StrScanner.new @tokens, fixnum_or_range, @bound
      clone_for pos: fixnum_or_range
    when Range
      # StrScanner.new @tokens, fixnum_or_range.begin, fixnum_or_range.end
      clone_for pos: fixnum_or_range.begin, bound: fixnum_or_range.end
    end
  end

  # Advance self past the end of s2
  def past s2
    clone_for pos: s2.bound
  end

  # return a version of self that ends where s2 begins
  def except s2
    return self if !s2 || s2.pos > @bound
    clone_for bound: s2.pos
  end

  # Return a stream from the end of the first scanner to the beginning of the second.
  def between first, second
    # NokoScanner.new tokens, first&.bound || @pos, second&.pos || @bound
    clone_for pos: first&.bound, bound: second&.pos
  end

  # Make the end of the stream coincident with another stream
  def encompass s2
    @bound = s2.bound if s2.bound > @bound
    self
  end

  # Return a stream whose boundaries are clipped to another stream
  def within s2_or_range
    range = s2_or_range.is_a?(Range) ? s2_or_range : s2_or_range.range
    if range.first < @bound && range.last > @pos
      # NokoScanner.new tokens, [@pos, range.first].max, [@bound, range.last].min
      clone_for pos: [@pos, range.first].max, bound: [@bound, range.last].min
    else
      # NokoScanner.new tokens, @pos, @pos
      clone_for bound: @pos
    end
  end

  def move_to newpos
    @pos = [[0, newpos].max, @bound].min
  end

  # Progress the scanner to follow the next newline character, optionally constraining the result to within a whole line
  def toline within = false, pos: @pos, bound: @bound
    @tokens.for_lines(range: pos...bound, inline: within) do |newpos, newbound|
      return clone_for(pos: newpos, bound: newbound)
    end
    nil
  end

  # Is the token stream at position pos immediately following a newline?
  def atline?
    @pos == 0 || toline(pos:@pos-1)&.pos == @pos
  end

  # Methods defined by NokoScanner
  def enclosing_classes
    []
  end

  def method_missing name, *args
    x=2
  end

end

# Scan an input (space-separated) stream. When the stream is exhausted, #more? returns false
class StrScanner < Scanner
  attr_reader :tokens # :length

  # StrScanner provides reading services for a succession of tokens. Initialized with either
  # -- a String, which will be tokenized
  # -- an Array of strings
  def initialize string_or_strings, pos = 0, bound = nil
    # We include punctuation and delimiters as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @tokens = string_or_strings.is_a?(String) ? StringTokens.new(string_or_strings) : string_or_strings
    @bound = bound || @tokens.length
    @pos = (pos < @bound) ? pos : @bound
  end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  # Divide the stream according to a comma-separated list and return an array of scanners, one for each partition
  def partition how: :list, elide_parentheses: true
    cl = self.rest 0
    candidate = self
    depth = 0
    result = [ ]
    while cl.more? do
      case this = cl.peek
      when '('
        depth = depth + 1
      when ')'
        depth = depth - 1
      when ',', 'and'
        # Add the scanner to the list if not within parentheses
        if depth == 0
          result << candidate.except(cl) if candidate.pos != cl.pos
          candidate = cl.rest
          break unless this == ','
        end
      end
      cl.first
    end
    return result + [ candidate ]
  end

  def to_s limit_or_range = @bound, nltr: false, trunc: nil
    range = limit_or_range.is_a?(Range) ? limit_or_range : @pos...limit_or_range
    @tokens[range].join(' ')
  end

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars = 1
    if @pos < @bound # @length
      (nchars == 1) ? @tokens[@pos] : @tokens[@pos...(@pos + nchars)].join(' ')
    else
      ''
    end
  end

  # Iterate through a set of scanners organized around EOL
  # :atline: report the next scanner that starts at a line (excluding empty lines)
  # :inline: do likewise, except terminate the scanner at the following EOL
  # It may return nil, in which case the next iteration goes to the subsequent token
  def for_each options={}, &block
    options = options.compact # Ignore flags that are set with nil
    @tokens.for_lines(range: @pos...@bound, inline: options[:inline]) do |pos, bound|
      # yield(StrScanner.new @tokens, pos, bound)
      yield(clone_for pos: pos, bound: bound)
    end
  end

  protected

  # Replicate a scanner for a new range, optionally constrained to the existing bounds
  def clone_for pos: nil, bound: nil, constrained: false
    pos ||= @pos # In the event that nil is passed
    bound ||= @bound
    if constrained
      StrScanner.new @tokens, [pos, @pos].max, [bound, @bound].min
    else
      StrScanner.new @tokens, [pos, 0].max, [bound, @tokens.count].min
    end
  end

end

class NokoScanner < Scanner
  attr_reader :nkdoc, :tokens
  delegate :pp, to: :nkdoc
  delegate :elmt_bounds, :token_starts, :token_index_for, :token_range_for_subtree,
           :enclose_tokens, :enclose_selection, to: :tokens

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc_or_nktokens_or_html, pos = 0, bound = nil # length=nil
    # Take the parameters as instance variables, creating @tokens if nec.
    case nkdoc_or_nktokens_or_html
    when NokoTokens
      @tokens = nkdoc_or_nktokens_or_html
      @nkdoc = nkdoc_or_nktokens_or_html.nkdoc
    when String
      @nkdoc = Nokogiri::HTML.fragment nkdoc_or_nktokens_or_html
      @tokens = NokoTokens.new @nkdoc
    else # It's a Nokogiri doc!
      @nkdoc = nkdoc_or_nktokens_or_html
      @tokens = NokoTokens.new nkdoc_or_nktokens_or_html
    end
    @bound = bound || @tokens.length
    @pos = (pos <= @bound) ? pos : @bound
  end

  # Return the stream of tokens as an array of strings
  def strings
    tokens.collect { |token| token.is_a?(NokoScanner) ? token.strings : token }.flatten
  end       

  def peek ntokens = 1
    if @pos < @bound # @length
      if ntokens == 1
        tokens[@pos]
      elsif tokens[@pos...(@pos + ntokens)].all? { |token| token.is_a? String } # ONLY IF NO TOKENS
        tokens[@pos...(@pos + ntokens)].join(' ')
      end
    end
  end

  # Output version of #peek: the original text, rather than a joined set of tokens
  def to_s limit_or_range = @bound, nltr: false, trunc: nil
    range = limit_or_range.is_a?(Range) ? limit_or_range : @pos...limit_or_range
    # peek limit-@pos      Gives tokens joined by a space: not quite the same thing
    str = tokens.text_from range.begin, range.end # @pos, limit
    str = str.truncate trunc if trunc
    str = str.gsub "\n", '\n' if nltr
    str
  end

  # Progress the scanner to follow the next newline character, optionally constraining the result to within a whole line
  def toline within = false
    # Find the location of the next line (boundary between nl and non-nl).
    # NB: skips over multiple nls;
    # returns the input if opos is already at a boundary (the better to identify the first line in the stream)
    # We give preference to "newline" status via CSS: at the beginning of <p> or <li> tags, or after <br>
    s1 = super # Consult the tokens for linebreaks
    s2 = on_css_match((within ? :in_css_match : :at_css_match) => 'p,li')
    s3 = on_css_match(:after_css_match => 'br')
    inorder = [s1, s2, s3].compact.sort { |sc1, sc2| sc1.pos <=> sc2.pos }
    return nil if !(result = inorder.first)
    result = goto result # Restrict the next line to within our scanner
    return result unless within
    # Need to find an end at the next line
    s4 = result.rest.on_css_match :at_css_match => 'p,li,br'
    s5 = super( false, pos: result.pos+1)
    # Constrain the result to the beginning of the next node, if any
    result.except (s4 && s5) ? (s4.pos < s5.pos ? s4 : s5) : (s4 || s5)
  end

  # Divide the stream according to a comma-separated list and return an array of scanners, one for each partition
  def partition how: :list, elide_parentheses: true
    cl = self.rest 0
    candidate = self
    depth = 0
    result = [ ]
    while cl.more? do
      case this = cl.peek
      when '('
        depth = depth + 1
      when ')'
        depth = depth - 1
      when ',', 'and', 'or'
        # Add the scanner to the list if not within parentheses
        if depth == 0
          result << candidate.except(cl) if candidate.pos != cl.pos
          candidate = cl.rest
          break unless this == ','
        end
      end
      cl.first
    end
    return result + [ candidate ]
  end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  # Test certain conditions about the current token. According to key on h, test
  #   after_elmt: token is immediately preceded by a tag that matches(nominally <br>)
  #   within_elmt: token is the first non-blank content within the element
  #   newline: the token is preceded by a newline
  def is_at? h
    tedata = text_elmt_data
    if tedata.prior_text.blank? # Only counts at beginning of a text element
      start = tedata.text_element
      if selector = h[:after_elmt]
        previous = start.previous
        while previous do
          return self if previous.matches?(selector)
          return if previous.inner_text.present?
          previous = previous.previous
        end
      elsif selector = h[:within_elmt]
        # We must be the first non-blank element within an element
        start.ancestors.each do |ancestor|
          return if ancestor.is_a? Nokogiri::HTML::DocumentFragment
          if ancestor.matches? selector
            ancestor.traverse do |node|
              return within_css_match(ancestor) if node == start
              return if node.text? && node.inner_text.present?
            end
          end
        end
        parent = start.parent
        previous = start.previous
        while previous do
          return false if previous.inner_text.present?
        end
      elsif selector = h[:newline]
      end
    end
  end

# Function for scanning for a result
  # Call a block with a scanner for each stop in self as controlled by the options:
  # :atline moves the scanner to the first token that begins a line (possibly this one)
  # :inline as with :atline, but foreshortens it to a single line
  # :at_css_match goes to the next token within an element matching the provided selector
  # :in_css_match as with :at_css_match, but foreshortens it to the contents of the matching element
  # :after_css_match goes to the token after the matching element (typically a br tag)
  # The block takes a scanner for the current location, and should return a scanner after consumption
  # It may return nil, in which case the next iteration goes to the subsequent token
  def for_each options={}, &block
    case options.keys.first
    when :inline, :atline
      @tokens.for_lines(range: @pos...@bound, inline: options[:inline]) { |pos, bound| yield(NokoScanner.new @tokens, pos, bound) }
    when :at_css_match, :in_css_match, :after_css_match
      for_css options, &block
    end
  end

  # Return a scanner, derived from the instance's Nokogiri DOM, restricted to the given CSS match
  def within_css_match selector_or_node
    if range = @tokens.dom_range(selector_or_node)
      return NokoScanner.new @tokens, range.begin, range.end
    end
  end

  def scanner_for_range range, how=nil
    if range.begin >= @pos
      case how
      when :in_css_match, nil
        NokoScanner.new @tokens, range.begin, range.end if range.end > range.begin
      when :at_css_match
        range == (@pos..@bound) ? self : NokoScanner.new(@tokens, range.begin, range.end)
      when :after_css_match
        NokoScanner.new @tokens, range.end
      end
    end
  end

  # Return a scanner that matches the spec.
  # spec: a Hash with one key-value pair. In all cases, the value is a CSS selector
  # -- if the key is :in_css_match, find the first node that matches the css and return a scanner for all and only that node's contents
  # -- if the key is :at_css_match, find the first node that matches the css and return a scanner that starts with that node's contents
  #   and ends at the next node that matches the css
  # -- if the key is :after_css_match, find the first node that matches the the css and return a scanner that starts after that node
  def on_css_match spec
    flag, selector = spec.to_a.first # Fetch the key and value from the spec
    return nil if selector.blank?
    @tokens.dom_ranges(spec) do |range, nokonode|
      # Reject empty ranges for :in_css_match, because
      # 1) it can't be incremented beyond, and
      # 2) an empty set of tokens can't be matched anyway
      # In general, this is an artifact of the ambiguity inherent in expressing ranges as tokens
      next if flag == :in_css_match && range.size < 1
      # Look at the first range that starts after this scanner, and return the part of the match within the scanner's bounds
      return (scanner_for_range(range, flag) if range.begin < @bound) if range.begin >= @pos
    end
    nil
  end

  # Return an ARRAY of scanners, as above
  def on_css_matches spec
    flag, selector = spec.to_a.first # Fetch the key and value from the spec
    @tokens.dom_ranges(spec) { |range, nokonode| scanner_for_range range, flag }.compact
  end

  # Divide the scanner into multiple scanners at tokens matching the matcher
  def split matcher
    token_index = @pos
    prev_start = @pos
    results = []
    while token_index < @bound do
      if tokens[token_index].match matcher
        results << NokoScanner.new(@tokens, prev_start, token_index) if token_index > prev_start
        prev_start = token_index+1
      end
      token_index += 1
    end
    results << NokoScanner.new(@tokens, prev_start, token_index) if token_index > prev_start
    results
  end

  # Provide xpath and offset for locating the current position in the document
  def xpath terminating = false
    @nkdoc.children.first
    ted = TextElmtData.new elmt_bounds, @tokens.character_position_at_token(@pos) * (terminating ? -1 : 1)
    ted.xpath
  end

  def enclose_to limit, rp_elmt_class:, tag: nil, value: nil
    return unless limit > pos
    @tokens.enclose_tokens @pos, limit, tag: tag, rp_elmt_class: rp_elmt_class, value: value
  end

  # Provide the text element data for the current character position
  def text_elmt_data pos = @pos
    @tokens.text_elmt_data(pos) if pos < @bound
  end

  def text_element pos = @pos
    text_elmt_data(pos)&.text_element
  end

  def parent_tagged_with token
    text_elmt_data&.parent_tagged_with token
  end

  def descends_from? tag: nil, token: nil
    nknode_descends_from? text_elmt_data.text_element, tag: tag, token: token if text_elmt_data
  end

  # What :rp_* classes have been used on the ancestors of the current text element?
  def enclosing_classes
    @tokens.enclosing_classes_at @pos
  end

  # Do the text elements bracketed by my range have a common ancestor with the given tag and token?
  # If coextensive is true, the ancestor qualifies only if any text it has outside the range is blank
  def ancestor_matching tag: nil, token: nil, coextensive: true
    # Get minimal enclosing text
    te_begin, te_end = text_elmt_data.advance_over_space, text_elmt_data(-bound).retreat_over_space
    common_ancestors = (te_begin.ancestors & te_end.ancestors)
    qualified = []
    common_ancestors[0..-2].each do |anc| # Exclude the top-level fragment from consideration
      # Quit when we hit an ancestor that has excessive text
      break if coextensive && ((te_begin.prior_text within: anc).present? || te_end.subsq_text(within: anc).present?)
      qualified << anc
    end
    # Among the qualified ancestors, return the highest-level one that matches BOTH tag and token, or token, or tagname
    qualified.reverse.each do |anc|
      return anc if (tag.blank? || (anc.name == tag)) && (token.blank? || (nknode_has_class? anc, token.to_s))
    end
    nil
  end

  # Get a scanner whose position is past the end of the given nokonode or nokoscanner,
  # aka the end of the nokonode's last text element
  def past nokonode_or_nokoscanner
    if nokonode_or_nokoscanner.is_a?(NokoScanner)
      return NokoScanner.new tokens, nokonode_or_nokoscanner.bound, @bound
    else
      nokonode = nokonode_or_nokoscanner
    end
    last_text_element = nil
    nokonode.traverse do |related|
      last_text_element = related if related.text?
    end
    # Advance the position marker until we reach the end of the last text element in the parent
    new_pos = @pos
    global_token_offset = @tokens.character_position_at_token new_pos
    ted = TextElmtData.new elmt_bounds, global_token_offset # Locate the text element that we're in
    # NB: we assume that a newly-allocated text element encompasses the requisite token offset
    while true do
      new_pos += 1
      break if new_pos == @bound
      global_token_offset = @tokens.character_position_at_token new_pos
      next if ted.encompasses_offset global_token_offset # Continue with the the current text element
      # Now that we've passed up one text element, we check if there's more
      break if ted.text_element == last_text_element # If this is the last text element in the nokonode, we're done
      # Advance to the NEXT text element
      ted = TextElmtData.new elmt_bounds, global_token_offset
    end
    NokoScanner.new tokens, new_pos, @bound
  end

  protected

  attr_writer :pos, :bound

  # Replicate a scanner for a new range, optionally constrained to the existing bounds
  def clone_for pos: nil, bound: nil, constrained: false
    pos ||= @pos # In the event that nil is passed
    bound ||= @bound
    if constrained
      NokoScanner.new tokens, [pos, @pos].max, [bound, @bound].min
    else
      NokoScanner.new tokens, [pos, 0].max, [bound, tokens.count].min
    end
  end

  private

  # Cycle through CSS matches, calling the block on each match, per directive:
  # :in_css_match => call the block on a NokoScanner bounded by the CSS match
  # :at_css_match => call the block on a NokoScanner that begins at the CSS match but is otherwise unbounded
  # :after_css_match => call the block on a NokoScanner that begins after the CSS match but is otherwise unbounded
  def for_css options={}, &block
    # Now we can assume there's a CSS matching directive
    subscanner = clone
    directive, selector = options.to_a.first
    begin # Confirm the validity of the selector
      sample = nkdoc.at_css selector
    rescue Exception => err
      return []
    end
    # If the whole selector provides no results, try a terminating subpath
    while !sample && selector.sub!(/.*\s+/, '') do
      begin # Confirm the validity of the selector
        sample = nkdoc.at_css selector
      rescue Exception => err
        # Try the next subpath on error
        sample = nil
      end
    end
    return [] unless sample # Give up unless at least one match found

    (matcher = Hash.new)[((directive == :after_css_match) ? :in_css_match : directive)] = selector
    subscanners = []
    while (subscanner = subscanner.on_css_match(matcher)) do
      # The subscanner's bounds are those of the css match
      # We need to know where (next_pos) to start the next search
      case directive
      when :in_css_match
        next_pos = subscanner.bound
      when :at_css_match
        next_pos = subscanner.pos+1
        subscanner.bound = @bound
      when :after_css_match # Remove the bounding constraint on the subscanner
        subscanner.pos = subscanner.bound
        next_pos = subscanner.pos+1
        subscanner.bound = @bound
      end
      subscanners << subscanner
      break unless subscanner.more? # No more content
      subscanner =
          case directive
          when :in_css_match
            NokoScanner.new tokens, next_pos, @bound
          when :at_css_match
            subscanner.rest
          when :after_css_match
            subscanner.rest
          end
    end
    if directive == :at_css_match
      # Terminate each subscanner at the beginning of the next
      subscanners[0..-2].each_index { |ix| subscanners[ix].bound = subscanners[ix+1].pos }
    end
    result = block_given? ? subscanners.collect { |ss| yield(ss) } : subscanners
    result
  end
end
