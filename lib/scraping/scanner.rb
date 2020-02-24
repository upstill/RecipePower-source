require 'string_utils.rb'
require 'binsearch.rb'
require 'scraping/text_elmt_data.rb'

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

# Move all the text enclosed in the tree between anchor_elmt and focus_elmt, inclusive, into an enclosure that's a child of
# the common ancestor of the two.
 def assemble_tree_from_nodes anchor_elmt, focus_elmt, options={}
  html = html_enclosure(options) # insert=true
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first

  # We'll attach the new tree as the predecessor node of the anchor element's highest ancestor
  left_ancestor = (anchor_elmt if anchor_elmt.parent == common_ancestor) ||
      anchor_elmt.ancestors.find { |elmt| elmt.parent == common_ancestor }
  newtree =
      if options[:insert] != false
        left_ancestor.previous = html
        left_ancestor.previous
      else
        Nokogiri::HTML.fragment(html).children[0]
      end
  left_collector = left_ancestor.next
  
  highest_whole_left = anchor_elmt
  while (highest_whole_left.parent != common_ancestor) && !highest_whole_left.previous_sibling do
    highest_whole_left = highest_whole_left.parent
  end
  # Starting with the highest whole node, add nodes that are included in the selection to the new elmt
  right_collector = highest_whole_left.next
  newtree.add_child highest_whole_left
  while (right_collector.parent != common_ancestor)
    parent = right_collector.parent
    while (right_sib = right_collector.next) do
      right_collector = right_sib.next
      newtree.add_child right_sib
    end
    right_collector = parent
  end
  ## Now do the same with the right side, adding preceding elements
  # Find the highest node that can be moved whole
  highest_whole_right = focus_elmt
  while (highest_whole_right.parent != common_ancestor) && !highest_whole_right.next_sibling do
    highest_whole_right = highest_whole_right.parent
  end
  # Build a stack from the right node's ancestor below the common ancestor down to the highest whole right node
  stack = [ highest_whole_right ]
  while stack.last.parent != common_ancestor
    stack.push stack.last.parent
  end
  # Go down the tree, collecting all the siblings before and including each ancestor
  while ancestor = stack.pop
    while left_collector != ancestor do
      next_sib = left_collector.next_sibling
      newtree.add_child left_collector
      left_collector = next_sib
    end
    left_collector = ancestor.children[0] unless stack.empty?
  end
  newtree.add_child highest_whole_right
  newtree
end

def html_enclosure options={}
  tag = options[:tag] || 'div'
  classes = "rp_elmt #{options[:classes]}".strip
  "<#{tag} class='#{classes}'></#{tag}>" # For constructing the new node
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

end

# This class analyzes and represents tokens within a Nokogiri doc.
# Once defined, it (but not the doc) is immutable
class NokoTokens < Array
  attr_reader :nkdoc, :elmt_bounds, :token_starts, :bound # :length
  delegate :pp, to: :nkdoc
  def initialize nkdoc
    def to_tokens newtext = nil
      # Prepend the string to the priorly held text, if any
      if newtext
        newtext = @held_text + newtext if @held_text && (@held_text.length > 0)
      else
        held_len = @held_text.length
      end
      @held_text = tokenize((newtext || @held_text), newtext == nil) { |token, offset|
        push token
        @token_starts.push @processed_text_len + offset
      }
      @processed_text_len += newtext&.length || held_len
      @processed_text_len -= @held_text.length
    end

    def do_child child
      case
      when child.text?
        # Save this element and its starting point
        @elmt_bounds << [child, (@processed_text_len + @held_text.length)]
        to_tokens child.text
      when child.element?
        to_tokens "\n" if child.name.match(/^(p|br|li)$/)
        child.children.each { |j| do_child j }
      end
    end

    # Take the parameters as instance variables, creating @tokens if nec.
    @nkdoc = nkdoc.is_a?(String) ? Nokogiri::HTML.fragment(nkdoc) : nkdoc
    @elmt_bounds = []
    @token_starts = []
    @processed_text_len = 0
    @held_text = ''
    @nkdoc.children.each { |j| do_child j }
    to_tokens # Finally flush the last text

    # Make this data immutable! No transforms to the tree should affect any token
    @token_starts.freeze
    self.map &:freeze
    @bound = count
    self.freeze
  end

  def token_offset_at token_index
    @token_starts[token_index] || @processed_text_len
  end

  # What's the global character offset at the END of the token before the limiting token?
  def token_limit_at token_limit_index
    return 0 if token_limit_index == 0
    token_offset_at(token_limit_index-1) + self[token_limit_index-1].length
  end

  def elmt_offset_at token_index
    @elmt_bounds[token_index]&.last || @processed_text_len
  end

  # Return the string representing all the text given by the two token positions
  # NB This is NOT the space-separated join of all tokens in the range, b/c any intervening whitespace is not collapsed
  def text_from first_token_index, limiting_token_index
    pos_begin = token_offset_at first_token_index
    pos_end = token_limit_at limiting_token_index
    return '' if pos_begin == @processed_text_len # Boundary condition: no more text!

    teleft, teright = TextElmtData.for_range self, pos_begin...pos_end
    return teleft.delimited_text(pos_end) if teleft.text_element == teright.text_element

    left_ancestors = teleft.ancestors - teright.ancestors # All ancestors below the common ancestor
    right_ancestors = teright.ancestors - teleft.ancestors
    if topleft = left_ancestors.pop
      left_ancestors = [teleft.text_element] + left_ancestors
    else
      topleft = teleft.text_element
    end
    if topright = right_ancestors.pop
      right_ancestors = [teright.text_element] + right_ancestors
    else
      topright = teright.text_element # Special processing here
    end
    nodes =
        left_ancestors.collect do |left_ancestor|
          next_siblings left_ancestor
        end +
            (next_siblings(topleft) & prev_siblings(topright)) +
        right_ancestors.reverse.collect do |right_ancestor|
          prev_siblings right_ancestor
        end
    teleft.subsq_text + nodes.flatten.map(&:text).join + teright.prior_text
  end

  # Convenience method to specify requisite text in terms of tokens
  def enclose_by_token_indices first_token_index, limiting_token_index, options={}
    # enclose_by_global_character_positions token_offset_at(first_token_index), token_offset_at(limiting_token_index), options
    global_character_position_start = token_offset_at first_token_index
    global_character_position_end = token_limit_at limiting_token_index
    # Provide a hash of data about the text node that has the token at 'global_character_position_start'
    teleft, teright = TextElmtData.for_range self, global_character_position_start...global_character_position_end
    # teleft = text_elmt_data global_character_position_start
    # teright = text_elmt_data -(global_character_position_end)
    if teleft.text_element == teright.text_element
      # Both beginning and end are on the same text node
      # Either add the specified class to the parent, or enclose the selected text in a new span element
      # If the enclosed text is all alone in a span, just add to the classes of the span
      if teleft.parent.name == 'span' &&
          options[:classes] &&
          teleft.prior_text.blank? &&
          teright.subsq_text.blank? &&
          teleft.parent.children.count == 1
        teleft.parent[:class] << " #{options[:classes]}" unless teleft.parent[:class].split.include?(options[:classes])
      else
        teleft.enclose_to global_character_position_end, html_enclosure({tag: 'span'}.merge options )
        update
      end
    else
      enclose_by_text_elmt_data teleft, teright, options
    end
  end

  # Return the Nokogiri node that was built
  def enclose_by_selection anchor_path, anchor_offset, focus_path, focus_offset, options={}
    newnode = nil
    if anchor_path == focus_path
      anchor_offset, focus_offset = focus_offset, anchor_offset if anchor_offset > focus_offset
      first_te = TextElmtData.new self, anchor_path, anchor_offset
      newnode = first_te.enclose_to (first_te.local_to_global focus_offset ), html_enclosure({tag: :span}.merge options)
      update
    else
      first_te = TextElmtData.new self, anchor_path, anchor_offset
      last_te = TextElmtData.new self, focus_path, focus_offset
      # Need to ensure the selection is in the proper order
      if last_te.elmt_bounds_index < first_te.elmt_bounds_index
        first_te, last_te = last_te, first_te
      end
      # The two elmt data are marked, ready for enclosing
      newnode = enclose_by_text_elmt_data first_te, last_te, options
    end
    newnode
  end

  def enclose_by_text_elmt_data teleft, teright, options={}
    # Remove unselected text from the two text elements and leave remaining text, if any, next door
    teleft.split_left
    teright.split_right
    assemble_tree_from_nodes teleft.text_element, teright.text_element, options
    update
  end

=begin
  # Modify the Nokogiri document to enclose the strings designated by pos_begin and pos_end in a <div> of the given classes
  def enclose_by_global_character_positions global_character_position_start, global_character_position_end, options={}
    # Provide a hash of data about the text node that has the token at 'global_character_position_start'
    teleft = text_elmt_data global_character_position_start
    teright = text_elmt_data -(global_character_position_end)
    if teleft.text_element == teright.text_element
      # Both beginning and end are on the same text node
      # Either add the specified class to the parent, or enclose the selected text in a new span element
      if teleft.parent.name == 'span' &&
          options[:classes] &&
          teleft.prior_text.blank? &&
          teright.subsq_text.blank?
        teleft.parent[:class] << " #{options[:classes]}" unless teleft.parent[:class].split.include?(options[:classes])
      else
        teleft.enclose_to global_character_position_end, html_enclosure({tag: 'span'}.merge options )
        update
      end
    else
      enclose_by_text_elmt_data teleft, teright, options
    end
  end
=end

  # What is the index of the token that includes the given offset (where negative offset denotes a terminating location)
  def token_index_for signed_global_char_offset
    global_char_offset = (terminating = signed_global_char_offset < 0) ? -signed_global_char_offset : signed_global_char_offset
    token_ix = binsearch token_starts, global_char_offset
    # A terminating mark at the beginning of a token is interpreted at the end of the prior token
    (terminating && token_starts[token_ix] == global_char_offset && token_ix > 0) ? (token_ix-1) : token_ix
  end

  # "Round" the character offset to the boundary of a token--either the first character (if a start mark) or
  # the limiting character (if a terminating one)
  def to_token_bound signed_global_char_offset
    token_ix = token_index_for signed_global_char_offset
    token_start = token_starts[token_ix]
    signed_global_char_offset < 0 ? -(token_start+self[token_ix].length) : token_start
  end

  # Raise an error if a proposed marker doesn't conform to token bounds:
  # -- It can't be within a token
  # -- A beginning marker must be at the head of a token
  # -- An ending marker must be at the end of the token
  def valid_mark? signed_global_char_offset
    return true if to_token_bound(signed_global_char_offset) == signed_global_char_offset
    raise "TextElmtData error: proposed marker #{signed_global_char_offset} violates token constraints"
  end

  # Provide TextElmtData objects for the beginning and ending of the (globally expressed) range.
  # If both ends of the range are in the same Nokogiri text element, the same TextElmtData object gets returned.
  # NB: if either end of the range falls inside a token, it's rounded to token boundaries
  def text_elmt_data_for_range global_range
    # Round the range to the boundaries of a token
    # Identify the token (by index) that the range starts in
    start_ix = binsearch token_starts, global_range.first
    # Start the range at the beginning of the token
    global_range = token_starts[start_ix]...global_range.last if global_range.first > token_starts[start_ix]

    # Identify the token (by index) that the range ends in
    end_ix = binsearch token_starts, global_range.last
    # If the range ends at the beginning of a token, identify the previous token
    end_ix -= 1 if token_ix > 0 && token_starts[end_ix] == global_char_offset
    # Get the character offset of the end of the token
    token_end = token_starts[end_ix] + self[endix].length
    # End the range at the end of the token
    global_range = global_range.first...token_end if global_range.last < token_end
    return TextElmtData.for_range(self, global_range)
  end

  def update
    # Because Nokogiri can replace nodes willy-nilly, let's make sure that the elmt_bounds are up to date
    ix = 0
    nkdoc.traverse do |node|
      if node.text?
        @elmt_bounds[ix][0] = node
        ix += 1
      end
    end
  end

  # Extract the text element data for the character "at" the given global position.
  # A negative sign on signed_global_char_offset signifies that this position terminates a selection.
  def text_elmt_data global_char_offset
    if global_char_offset < 0
      global_char_offset = -global_char_offset
      token_ix = binsearch token_starts, global_char_offset
      token_ix -= 1 if token_ix > 0 && token_starts[token_ix] == global_char_offset
      # Clamp the global character offset to be within the token
      token_end = token_starts[token_ix] + self[token_ix].length
      global_char_offset = token_end if (global_char_offset > token_end)
      global_char_offset = -global_char_offset
    end
    TextElmtData.new self, global_char_offset
  end

  # Provide the token range enclosed by the CSS selector
  # RETURNS: if found, a Range value denoting the first token offset and token limit in the DOM.
  # If not found, nil
  def dom_range selector
    return unless found = nkdoc.search(selector).first
    range_from_subtree found
  end

  # Do the above but for EVERY match on the DOM. Returns a possibly empty array of values
  def dom_ranges selector
    nkdoc.search(selector)&.map { |found| range_from_subtree found } || []
  end

  def range_from_subtree found
    first_text_element = nil
    last_text_element = nil
    found.traverse do |child|
      if child.text?
        last_text_element = child
        first_text_element ||= child
      end
    end
    first_pos = last_pos = last_limit = nil
    @elmt_bounds.each_with_index do |pair, index|
      if !first_pos && pair.first == first_text_element
        first_pos = pair.last
      end
      if !last_pos && pair.first == last_text_element
        last_pos = pair.last
        last_limit = elmt_offset_at(index+1)
        break
      end
    end
    # Now we have an index in the elmts array, but we need a range in the tokens array.
    # Fortunately, that is sorted by index, so: binsearch!
    first_token_index = binsearch(@token_starts, first_pos) || 0 # Find the token at this position
    first_token_index += 1 if token_offset_at(first_token_index) < first_pos # Round up if the token overlaps the boundary
    last_token_index = binsearch @token_starts, last_limit # The last token is a limit
    last_token_index += 1 if (token_offset_at(last_token_index)+self[last_token_index].length) <= last_limit # Increment if token is entirely w/in the element
    return first_token_index...last_token_index
  end
end

class NokoScanner
  attr_reader :nkdoc, :pos, :bound, :tokens
  delegate :pp, to: :nkdoc
  delegate :elmt_bounds, :token_starts, :token_offset_at, :enclose_by_token_indices, :text_elmt_data, to: :tokens

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

  # Is the scanner at a newline: either the first token, or a token preceded by "\n"
  def atline?
    (@pos >= 0) && (tokens[@pos-1] == "\n")
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
    newpos = @pos + ntokens
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
    NokoScanner.new tokens, @pos, s2.pos # (newpos > @length ? @length : newpos), @length
  end

  # Make the end of the stream coincident with another stream
  def encompass s2
    # @length = s2.length
    @bound = s2.bound if s2.bound > @bound
  end

  # Return a scanner, derived from the instance's Nokogiri DOM, restricted to the given CSS match
  def within_css_match str
    if range = @tokens.dom_range(str)
      return NokoScanner.new @tokens, range.begin, range.end
    end
  end

  # Return an ARRAY of scanners, as above
  def within_css_matches str
    @tokens.dom_ranges(str).map { |range|
      next if range.begin < @pos
      NokoScanner.new @tokens, range.begin, range.end
    }.compact
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

end
