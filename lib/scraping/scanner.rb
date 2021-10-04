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

def seekline tokens, within, opos, obound, delimiter = nil
  delimiter = "\n" unless delimiter.is_a?(String)
  if (newpos = opos) > 0 && tokens[newpos] != delimiter
    while (newpos < obound) && (tokens[newpos-1] != delimiter) do
      newpos += 1
    end
  end
  if newpos < obound # Should we really be returning an empty scanner once we hit the end?
    if within
      newbound = newpos
      while newbound < obound do
        newbound += 1
        break if tokens[newbound-1] == delimiter
      end
    else
      newbound = obound
    end
    yield newpos, newbound
  end
end

# A Scanner object provides a stream of input strings, tokens, previously-parsed entities, and delimiters
# This is an "abstract" class for defining what methods the Scanner provides
class Scanner < Object
  attr_reader :pos

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek ntokens = 1

  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first

  end

  # Move past the current string, adjusting 'next' and returning a stream for the remainder
  def rest nchars = 1

  end

  # Move past the end, returning an exhausted stream
  def end

  end

  # The stream in its entirety
  def all

  end

  def more?
    @pos < @bound # @length
  end

=begin
  # Skip any newlines
  def past_newline
    result = self
    while result.peek == "\n"
      result = result.rest
    end
    result
  end
=end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  # Provide a string representing the content of the stream from its current position, terminating at the bound
  def to_s limit = @bound
    peek (limit - @pos)
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

end

# Scan an input (space-separated) stream. When the stream is exhausted, #more? returns false
class StrScanner < Scanner
  attr_reader :strings, :pos, :bound # :length

  def initialize string_or_strings, pos = 0, bound = nil
    # We include punctuation and delimiters as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @strings = string_or_strings.is_a?(String) ? tokenize(string_or_strings) : string_or_strings
    @pos = pos
    # @length = @strings.count
    @bound = bound || @strings.count
  end

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars = 1
    if @pos < @bound # @length
      (nchars == 1) ? @strings[@pos] : @strings[@pos...(@pos + nchars)].join(' ')
    else
      ''
    end
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first nchars = 1
    if @pos < @bound # @length
      f = @strings[@pos...(@pos + nchars)]&.join(' ')
      @pos += nchars
      @pos = @bound if @pos > @bound # @length if @pos > @length
      f
    end
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars = 1
    newpos = @pos + nchars
    # StrScanner.new(@strings, (newpos > @length ? @length : newpos))
    StrScanner.new @strings, (newpos > @bound ? @bound : newpos), @bound
  end

  # Return this scanner, exhausted
  def end
    StrScanner.new @strings, @bound, @bound
  end

  def all
    StrScanner.new @strings, 0, @bound
  end

  # Progress the scanner to precede the next newline character, optionally constraining the result to within a whole line
  def toline within = false, delimiter = "\n"
    seekline @strings, within, @pos, @bound, delimiter do |newpos, newbound|
      StrScanner.new @strings, newpos, newbound
    end
  end

  # return a version of self that ends where s2 begins
  def except s2
    return self if !s2 || s2.pos > @bound
    s2 ? StrScanner.new(@strings, @pos, s2.pos) : self
  end

  # Iterate through a set of scanners organized around EOL
  # :atline: report the next scanner that starts at a line (excluding empty lines)
  # :inline: do likewise, except terminate the scanner at the following EOL
  # It may return nil, in which case the next iteration goes to the subsequent token
  def for_each options={}, &block
    options = options.compact # Ignore flags that are set with nil
    results = []
    pos = @pos
    while pos < @bound do
      # Consume EOL characters at the beginning
      while (pos < @bound) && @strings[pos] == "\n" do
        pos += 1
      end
      break if pos == @bound # No more material
      # Otherwise, we know we have at least one non-EOL character
      # Seek the end of the non-EOL run
      bound = pos+1
      # Find the position of the next EOL, or the end of the buffer
      while (bound < @bound) && @strings[bound] != "\n" do
        bound += 1
      end
      # If :inline, truncate it at the next EOL character
      subscanner = StrScanner.new @strings, pos, (options[:inline] ? bound : @bound)
      if result = (block_given? ? yield(subscanner) : subscanner)
        results << result
      end
      pos = bound
    end
    results
  end

end

class NokoScanner # < Scanner
  attr_reader :nkdoc, :pos, :bound, :tokens
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
  def to_s limit = @bound
    # peek limit-@pos      Gives tokens joined by a space: not quite the same thing
    tokens.text_from @pos, limit
  end

  # Report the token no matter if the position is beyond the bound
  def token_at
    tokens[@pos]
  end

  # Progress the scanner to follow the next newline character, optionally constraining the result to within a whole line
  def toline within = false, delimiter = "\n"
    # We give preference to "newline" status via CSS: at the beginning of <p> or <li> tags, or after <br>
    s1 = seekline(@tokens, within, @pos, @bound, delimiter) do |newpos, newbound|
      NokoScanner.new @tokens, newpos, newbound
    end
    s2 = on_css_match((within ? :in_css_match : :at_css_match) => 'p,li')
    s3 = on_css_match(:after_css_match => 'br')
    inorder = [s1, s2, s3].compact.sort { |sc1, sc2| sc1.pos <=> sc2.pos }
    return nil if !(result = inorder.first)
    result = goto result # Restrict the next line to within our scanner
    return result unless within
    # Need to find an end at the next line
    s4 = result.rest.on_css_match :at_css_match => 'p,li,br'
    s5 = seekline(@tokens, false, result.pos + 1, @bound, delimiter) do |newpos, newbound|
      NokoScanner.new @tokens, newpos, newbound
    end
    # Constrain the result to the beginning of the next node, if any
    result.except (s4 && s5) ? (s4.pos < s5.pos ? s4 : s5) : (s4 || s5)
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first ntokens = 1
    if str = peek(ntokens)
      @pos += ntokens
      @pos = @bound if @pos > @bound # @length if @pos > @length
    end
    str
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest ntokens = 1
    newpos = (ntokens < 0) ? @bound : (@pos + ntokens)
    NokoScanner.new tokens, (newpos > @bound ? @bound : newpos), @bound # (newpos > @length ? @length : newpos), @length
  end

  # Return this scanner, exhausted
  def end
    NokoScanner.new tokens, @bound, @bound
  end

  def all
    NokoScanner.new tokens, 0, @bound
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

  # Skip any newlines
  def past_newline
    result = self
    while result.peek == "\n"
      result = result.rest
    end
    result
  end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  def more?
    @pos < @bound # @length
  end

  # Create a scanner that starts where the given scanner starts
  def goto s2
    NokoScanner.new tokens, s2.pos, @bound
  end

  # Advance self past the end of s2
  def past s2
    NokoScanner.new tokens, s2.bound, @bound
  end

  # Create a scanner that ends at the given scanner
  def except s2
    return self if !s2 || s2.pos > @bound
    s2 ? NokoScanner.new(tokens, @pos, s2.pos) : self
  end

  # Make the end of the stream coincident with another stream
  def encompass s2
    # @length = s2.length
    @bound = s2.bound if s2.bound > @bound
    self
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
      for_lines options[:inline], &block
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
    @tokens.dom_ranges(spec).each do |range|
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
    ranges = @tokens.dom_ranges spec
    ranges.map { |range| scanner_for_range range, flag }.compact
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

  private

  # Cycle through the lines in a document, defined as non-empty streams of tokens bounded by newline, <br> or EOF
  def for_lines inline, &block
    results = []
    pos = @pos

    # Memoize an array of token positions for all <br> directives in the document.
    # This is used to truncate all lines at <br>
    @brs ||= nkdoc.search('br').map { |found| @tokens.token_range_for_subtree(found)&.begin }.compact
    brpos =
    if brix = binsearch(@brs, pos)
      brix += 1 if @brs[brix] < pos
      @brs[brix]
    else
      @brs[brix = 0]
    end
    # Now brix denotes the index in the @brs array of the token position (brpos) of the next <br>
    while pos < @bound do
      # Consume EOL characters at the beginning
      while (pos < @bound) && @tokens[pos] == "\n" do
        pos += 1
      end
      break if pos == @bound # No more material
      # Otherwise, we know we have at least one non-EOL character
      # Seek the end of the non-EOL run
      bound = pos+1
      while brpos && brpos <= bound do
        brpos = @brs[brix += 1] # Look for the next <br> directive
      end
      # Find the position of the next EOL, or the end of the buffer, or the position of the next <br> directive
      while (bound < @bound) && !(@tokens[bound] == "\n" || bound == brpos) do
        bound += 1
      end
      # If :inline, truncate it at the next EOL character
      subscanner = NokoScanner.new @tokens, pos, (inline ? bound : @bound)
      if result = (block_given? ? yield(subscanner) : subscanner)
        results << result
      end
      pos = bound
    end
    results
  end

  # Cycle through CSS matches, calling the block on each match, per directive:
  # :in_css_match => call the block on a NokoScanner bounded by the CSS match
  # :at_css_match => call the block on a NokoScanner that begins at the CSS match but is otherwise unbounded
  # :after_css_match => call the block on a NokoScanner that begins after the CSS match but is otherwise unbounded
  def for_css options={}, &block
    # Now we can assume there's a CSS matching directive
    subscanner = clone
    results = []
    directive, selector = options.to_a.first
    subscanners = []
    while (subscanner = subscanner.on_css_match(in_css_match: selector) || subscanner.on_css_match(at_css_match: selector)) do
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
    block_given? ?
      subscanners.each { |ss| yield(ss) } :
      subscanners
  end
end
