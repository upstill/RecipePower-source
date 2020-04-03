require 'string_utils.rb'
require 'binsearch.rb'
require 'scraping/text_elmt_data.rb'
require 'scraping/noko_tokens.rb'

# Is the node ready to delete?
def node_empty? nokonode
  return nokonode.text.match /^\n*$/ if nokonode.text? # A text node is empty if all it contains are newlines (if any)
  nokonode.children.blank? || nokonode.children.all? { |child| node_empty? child }
end

# Return all the siblings BEFORE this node
def prev_siblings nokonode
  found = false
  nokonode.parent.children.collect { |child| child unless (found ||= child == nokonode) }.compact
end

# Return all the siblings AFTER this node
def next_siblings nokonode
  found = false
  nokonode.parent.children.collect { |child| found ? child : (found ||= child == nokonode ; nil) }.compact
end

# Can enclosure proceed? At first, this test merely heads off making a redundant enclosure
def enclosable? subtree, anchor_elmt, focus_elmt, options
  options[:classes].blank? || !nknode_has_class?(subtree, options[:classes])
end

def first_text_element node, blanks_okay=false
  node.traverse do |child|
    return child if child.text? && (blanks_okay || child.text.present?)
  end
end

def last_text_element node, blanks_okay=false
  last = nil
  node.traverse do |child|
    last = child if child.text? && (blanks_okay || child.text.present?)
  end
  last
end

def predecessor_text tree, text_elmt
  prev = nil
  tree.traverse do |node|
    return prev if node == text_elmt # NB: will return nil if no predecessor
    if node.text?
      prev = node
    end
  end
end

def successor_text tree, text_elmt
  passed = false
  tree.traverse do |node|
    return node if passed && node.text?
    passed = true if node == text_elmt
  end
end

# An ancestor of a node is markable if the first text elmt and the last text element are the entirety of non-blank text
def scan_ancestors node, first_text_elmt, last_text_elmt
  while !node.fragment? &&
      first_text_element(node) == first_text_elmt &&
      last_text_element(node) == last_text_elmt do
    yield node
    node = node.parent
  end
end

# If possible, apply the classes to an ancestor of the two text elements
# "possible" means that all text of the ancestor before the first and after the last
# text element is blank
def tag_ancestor node, first_te, last_te, tag='span', classes=''
  tag, classes = 'span', tag if tag&.match('rp_')
  scan_ancestors node, first_te, last_te do |anc|
    if anc.name == tag&.to_s
      nknode_add_classes anc, "rp_elmt #{classes}"
      return anc
    end
  end
  nil
end

# Test that the nodes have a parent and appropriate siblings
def confirm_integrity *nodes
  nodes.each do |node|

  end
end

# Add a child to a node while ensuring that the child's old environment is maintained
def add_child node, newchild
  if (node == newchild) || (newchild.parent == node)
    return newchild.next
  end
  rtnval = newchild.next
  if newchild == node.next
    node.add_child newchild
    return node.next
  else
    node.add_child newchild
    return rtnval
  end
  begin
    orig_prev, orig_next = newchild.previous, newchild.next
    node_prev, node_next = node.previous, node.next
    newchild.remove # node.add_child newchild
    if orig_prev
      raise '1: Previous node lost its parent after removing' unless orig_prev.parent
      raise '2: Previous node not linked to next node after removing' unless orig_prev.next == orig_next
    end
    if orig_next
      raise '3: Next node lost its parent after removing' unless orig_next.parent
      raise '4: Next node not linked back to previous node after removing' unless orig_next.previous == orig_prev
    end
    node.add_child newchild
    if node == orig_prev && node.next != orig_next
      # Somehow the original next node has gotten unlinked from the DOM.
      return
    end
    if node == orig_next && node.prev != orig_prev
      return
    end
    if orig_prev
      raise '5: Previous node lost its parent after adding' unless orig_prev.parent
      raise '6: Previous node not linked to next node after adding' unless orig_prev.next == orig_next
    end
    if orig_next
      raise '7: Next node lost its parent after adding' unless orig_next.parent
      raise '8: Next node not linked back to previous node after adding' unless orig_next.previous == orig_prev
    end
    raise '9: New child not linked in with parent' unless newchild.parent == node
  rescue Exception => e
    x=2
  end

end

# Insert a node before the given node and return the former
def insert_before node_or_html, node
  begin
    old_prev = node.previous
    parent = node.parent
    node.previous = node_or_html
    newtree = node.previous
    if old_prev
      raise 'Prior node not relinked properly' unless old_prev.next == newtree
      raise 'Old previous lost its parent' unless old_prev.parent == parent
    end
    if node_or_html.is_a? String
      raise 'New node didn\'t get parent of its successor' unless newtree.parent == parent
    else
      raise 'New node didn\'t get parent of its successor' unless node_or_html.parent == parent
    end
  rescue Exception => e
    x=2
  end
  newtree
end


# Insert a node before the given node and return the former
def insert_after node, node_or_html
  begin
    old_next = node.next
    parent = node.parent
    node.next = node_or_html
    newtree = node.next
    if old_next
      raise 'Subsequent node not relinked properly' unless old_next.previous == newtree
      raise 'Old next lost its parent' unless old_next.parent == parent
    end
    if node_or_html.is_a? String
      raise 'New node didn\'t get parent of its successor' unless newtree.parent == parent
    else
      raise 'New node didn\'t get parent of its successor' unless node_or_html.parent == parent
    end
  rescue Exception => e
    x=2
  end
  newtree
end

# Move all the text enclosed in the tree between anchor_elmt and focus_elmt, inclusive, into an enclosure that's a child of
# the common ancestor of the two.
def assemble_tree_from_nodes anchor_elmt, focus_elmt, options = {}
  html = html_enclosure(options) # insert=true

  # Back the focus_elmt up as long as it's blank
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first
  
  # We can just apply the class to the parent element if the two text elements are the first and last text elements in the subtree
  while anchor_elmt.to_s.blank? do
    anchor_elmt = successor_text common_ancestor, anchor_elmt
  end
  while focus_elmt.to_s.blank? do
    focus_elmt = predecessor_text common_ancestor, focus_elmt
  end
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first # focus_elmt may have moved up the tree
  # If there's an ancestor with no preceding or succeeding text, mark that and return
  if anc = tag_ancestor(common_ancestor, anchor_elmt, focus_elmt, options[:tag], options[:classes])
    return anc
  end
  return common_ancestor unless enclosable? common_ancestor, anchor_elmt, focus_elmt, options

  # We'll attach the new tree as the predecessor node of the anchor element's highest ancestor
  left_ancestor = (anchor_elmt if anchor_elmt.parent == common_ancestor) ||
      anchor_elmt.ancestors.find { |elmt| elmt.parent == common_ancestor }
  newtree = nil
  left_collector = if options[:insert] != false
                     if anchor_elmt.parent == common_ancestor
                       newtree = insert_before html, left_ancestor
                       # left_ancestor.previous = html
                       # newtree = left_ancestor.previous
                       left_ancestor.next
                     else
                       newtree = insert_after left_ancestor, html
                       # left_ancestor.next = html
                       # newtree = left_ancestor.next
                       newtree.next
                     end
                   else
                     newtree = Nokogiri::HTML.fragment(html).children[0]
                     left_ancestor.next
                   end

  highest_whole_left = anchor_elmt
  while (highest_whole_left.parent != common_ancestor) && !highest_whole_left.previous_sibling do
    highest_whole_left = highest_whole_left.parent
  end
  # Starting with the highest whole node, add nodes that are included in the selection to the new elmt
  if highest_whole_left == focus_elmt
    add_child newtree, highest_whole_left
    return newtree
  end
  if (newtree.next == focus_elmt) # (newtree.next == highest_whole_left) && (highest_whole_left.next == focus_elmt)
    right_collector = add_child newtree, highest_whole_left # newtree.add_child highest_whole_left
    focus_elmt = newtree.next
  else
    right_collector = add_child newtree, highest_whole_left # newtree.add_child highest_whole_left
  end
  if right_collector
    while (right_collector.parent != common_ancestor)
      parent = right_collector.parent
      while (right_sib = right_collector.next) do
        right_collector = add_child newtree, right_sib # newtree.add_child right_sib
      end
      right_collector = parent
    end
  end
  ## Now do the same with the right side, adding preceding elements
  # Find the highest node that can be moved whole
  highest_whole_right = focus_elmt
  while (highest_whole_right.parent != common_ancestor) && !highest_whole_right.next_sibling do
    highest_whole_right = highest_whole_right.parent
  end
  # Build a stack from the right node's ancestor below the common ancestor down to the highest whole right node
  stack = [highest_whole_right]
  while stack.last.parent != common_ancestor
    stack.push stack.last.parent
  end
  # Go down the tree, collecting all the siblings before and including each ancestor
  while ancestor = stack.pop
    while left_collector && left_collector != ancestor do
      left_collector = add_child newtree, left_collector # newtree.add_child left_collector
    end
    left_collector = ancestor.children[0] unless stack.empty?
  end
  add_child newtree, highest_whole_right # newtree.add_child highest_whole_right
  validate_embedding newtree
end

# Special case: You can't put a <div> inside a <p>, so we may have to split the common ancestor to accommodate
def validate_embedding newtree
  if %w{ div ul li }.include? newtree.name
    # We have to split ancestors up to and including any <p>
    while newtree.ancestors.find { |node| node.name == 'p' } do
      parent = newtree.parent
      # If the interfering element has no successor or predecessor in the paragraph, simply hoist it up to be a sibling
      if !newtree.next
        parent.next = newtree
      elsif !newtree.previous
        parent.previous = newtree
      else
        # We have to split the paragraph, leaving the new tree between parts
        ix = parent.children.find_index { |child| child == newtree }
        parent.next = newtree
        # break if ix == parent.children.count # No more work to do if this is the last child of the parent
        newtree.next = newtree.document.create_element parent.name, parent.attributes
        # Move the paragraph content following the new tree into the new paragraph
        newtree.next.children = parent.children[ix..-1]
      end
    end
  end
  newtree
end

def html_enclosure options={}
  tag = options[:tag] || 'div'
  classes = "rp_elmt #{options[:classes]}".strip
  "<#{tag} class='#{classes}'></#{tag}>" # For constructing the new node
end

def seekline tokens, within, opos, obound
  if (newpos = opos) > 0 && tokens[newpos] != "\n"
    while (newpos < obound) && (tokens[newpos-1] != "\n") do
      newpos += 1
    end
  end
  if newpos < obound # Should we really be returning an empty scanner once we hit the end?
    if within
      newbound = newpos
      while (newbound < obound) && (tokens[newbound] != "\n") do
        newbound += 1
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

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  # Provide a string representing the content of the stream from its current position, terminating at the bound
  def to_s limit=@bound
    peek (limit - @pos)
  end

end

# Scan an input (space-separated) stream. When the stream is exhausted, #more? returns false
class StrScanner < Scanner
  attr_reader :strings, :pos, :bound # :length

  def initialize strings, pos = 0, bound = nil
    # We include punctuation and delimiters as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @strings = strings
    @pos = pos
    # @length = @strings.count
    @bound = bound || @strings.count
  end

  def self.from_string string, pos = 0
    self.new tokenize(string), pos
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
    StrScanner.new(@strings, (newpos > @bound ? @bound : newpos), @bound)
  end

  def more?
    @pos < @bound # @length
  end

  # Is the scanner at a newline: either the first token, or a token preceded by "\n"
  def atline?
    (@pos >= 0) && (@strings[@pos-1] == "\n")
  end

  # Progress the scanner to follow the next newline character, optionally constraining the result to within a whole line
  def toline within=false
    seekline @strings, within, @pos, @bound do |newpos, newbound|
      StrScanner.new @strings, newpos, newbound
    end
  end

end

class NokoScanner # < Scanner
  attr_reader :nkdoc, :pos, :bound, :tokens
  delegate :pp, to: :nkdoc
  delegate :elmt_bounds, :token_starts, :token_index_for, :token_offset_at, :enclose_by_token_indices, :enclose_by_selection, :text_elmt_data, to: :tokens

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc_or_nktokens_or_html, pos = 0, bound=nil # length=nil
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
    @pos = pos
  end

  def self.from_string html
    self.new Nokogiri::HTML.fragment(html)
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
  def to_s limit=@bound
    # peek limit-@pos      Gives tokens joined by a space: not quite the same thing
    tokens.text_from @pos, limit
  end

  # Report the token no matter if the position is beyond the bound
  def token_at
    tokens[@pos]
  end

  # Progress the scanner to follow the next newline character, optionally constraining the result to within a whole line
  def toline within = false
    # We give preference to "newline" status via CSS: at the beginning of <p> or <li> tags, or after <br>
    s1 = seekline(@tokens, within, @pos, @bound) do |newpos, newbound|
      NokoScanner.new @tokens, newpos, newbound
    end
    s2 = on_css_match((within ? :in_css_match : :at_css_match) => 'p,li')
    s3 = on_css_match(:after_css_match => 'br')
    inorder = [s1, s2, s3].compact
    if inorder.present?
      inorder.sort! { |sc1, sc2| sc1.pos <=> sc2.pos }
      result = inorder.shift
      # Constrain the result to the beginning of the next node, if any
      within ? result.except(inorder.shift) : result
    end
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

  # Create a scanner that ends at the given scanner
  def except s2
    return self if !s2 || s2.pos > @bound
    s2 ? NokoScanner.new( tokens, @pos, s2.pos) : self
  end

  # Make the end of the stream coincident with another stream
  def encompass s2
    # @length = s2.length
    @bound = s2.bound if s2.bound > @bound
  end

  # Get the text_elmt_data info for the current position
  def current_ted
    TextElmtData.new @tokens, @tokens.token_offset_at(@pos) # Locate the text element that we're in
  end

  # Test certain conditions about the current token. According to key on h, test
  #   after_elmt: token is immediately preceded by a tag that matches(nominally <br>)
  #   within_elmt: token is the first non-blank content within the element
  #   newline: the token is preceded by a newline
  def is_at? h
    tedata = current_ted
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

  # Return a scanner, derived from the instance's Nokogiri DOM, restricted to the given CSS match
  def within_css_match selector_or_node
    if range = @tokens.dom_range(selector_or_node)
      return NokoScanner.new @tokens, range.begin, range.end
    end
  end

  def scanner_for_range range, how
    if range.begin >= @pos
      case how
      when :in_css_match
        NokoScanner.new @tokens, range.begin, range.end
      when :at_css_match
        range == @pos..@bound ? self : NokoScanner.new(@tokens, range.begin, range.end)
      when :after_css_match
        NokoScanner.new @tokens, range.end
      end
    end
  end

  # Return a scanner that matches the spec.
  # spec: a Hash with one key-value pair. In all cases, the value is a CSS selector
  # -- if the key is :in_css_match, find the first node that matches the css and return a scanner for all and only that node's contents
  # -- if the key is :at_css_match, find the first node that matches the css and return a scanner that starts with that node's contents
  # -- if the key is :after_css_match, find the first node that matches the the css and return a scanner that starts after that node
  def on_css_match spec
    flag, selector = spec.to_a.first # Fetch the key and value from the spec
    @tokens.dom_ranges(selector).each do |range|
      if range.begin >= @pos &&
          range.end <= @bound &&
          newscanner = scanner_for_range(range, flag)
        return newscanner
      end
    end
    nil
  end

  # Return an ARRAY of scanners, as above
  def on_css_matches spec
    flag = spec.keys.first
    selector = spec[flag]
    ranges = @tokens.dom_ranges selector
    # For :at_css_match, ranges[i] runs to the beginning of ranges[i+1]
    ranges.each_index do |ix|
      ranges[ix] = ranges[ix].begin..(ranges[ix+1]&.begin || @bound)
    end if flag == :at_css_match
    ranges.map { |range| scanner_for_range range, flag }.compact
  end

  # Provide xpath and offset for locating the current position in the document
  def xpath terminating=false
    @nkdoc.children.first
    ted = TextElmtData.new @tokens, @tokens.token_offset_at(@pos)*(terminating ? -1 : 1)
    ted.xpath
  end

  def enclose_to limit, options={}
    return unless limit > pos
    @tokens.enclose_by_token_indices @pos, limit, options
  end

  # Provide the text element data for the current character position
  def text_elmt_data pos=@pos
    @tokens.text_elmt_data(@tokens.token_offset_at pos) if pos < @bound
  end

  def parent_tagged_with token
    text_elmt_data&.parent_tagged_with token
  end

  def descends_from? tag, token
    text_elmt_data&.descends_from? tag, token
  end

    # Get a scanner whose position is past the end of the given nokonode,
  # aka the end of the nokonode's last text element
  def past nokonode
    last_text_element = nil
    nokonode.traverse do |related|
      last_text_element = related if related.text?
    end
    # Advance the position marker until we reach the end of the last text element in the parent
    new_pos = @pos
    global_token_offset = @tokens.token_offset_at new_pos
    ted = TextElmtData.new @tokens, global_token_offset # Locate the text element that we're in
    # NB: we assume that a newly-allocated text element encompasses the requisite token offset
    while true do
      new_pos += 1
      break if new_pos == @bound
      global_token_offset = @tokens.token_offset_at new_pos
      next if ted.encompasses_offset global_token_offset  # Continue with the the current text element
      # Now that we've passed up one text element, we check if there's more
      break if ted.text_element == last_text_element # If this is the last text element in the nokonode, we're done
      # Advance to the NEXT text element
      ted = TextElmtData.new tokens, global_token_offset
    end
    NokoScanner.new tokens, new_pos, @bound
  end
end
