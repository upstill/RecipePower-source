require 'string_utils.rb'
require 'binsearch.rb'

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
def assemble_tree_from_nodes classes, anchor_elmt, focus_elmt, insert=true
  html = html_enclosure(classes)
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first

  # We'll attach the new tree as the predecessor node of the anchor element's highest ancestor
  left_ancestor = (anchor_elmt if anchor_elmt.parent == common_ancestor) ||
      anchor_elmt.ancestors.find { |elmt| elmt.parent == common_ancestor }
  newtree =
      if insert
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

def html_enclosure classes='', tag=:div
  if classes.is_a? Symbol
    classes, tag = '', classes
  end
  classes = "rp_elmt #{classes}".strip
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
=begin
      when child.attributes['class']&.value&.match(/\brp_elmt\b/)
        to_tokens
        self << NokoScanner.new(child)
=end
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

  def elmt_offset_at token_index
    @elmt_bounds[token_index]&.last || @processed_text_len
  end

  # Return the string representing all the text given by the two token positions
  def text_from first_token_index, limiting_token_index
    pos_begin = token_offset_at(first_token_index) ; pos_end = token_offset_at(limiting_token_index)
    teleft = text_elmt_data pos_begin
    if teleft.encompasses_offset pos_end
      return teleft.delimited_text(pos_end)
    end
    teright = text_elmt_data -(pos_end) # The TextElmtData for the terminating token
    left_ancestors = teleft.ancestors - teright.ancestors # All ancestors below the common ancestor
    right_ancestors = teright.ancestors - teleft.ancestors
    topleft = left_ancestors.pop || teleft.text_element ; topright = right_ancestors.pop || teright.text_element # Special processing here
    nodes = left_ancestors.collect { |left_ancestor| next_siblings left_ancestor } +
        (next_siblings(topleft) & prev_siblings(topright)) +
        right_ancestors.reverse.collect { |right_ancestor| prev_siblings right_ancestor }
    teleft.subsq_text + nodes.flatten.map(&:text).join + teright.prior_text
  end

  # Convenience method to specify requisite text in terms of tokens
  def enclose_by_token_indices first_token_index, limiting_token_index, classes=''
    enclose_by_global_character_positions token_offset_at(first_token_index), token_offset_at(limiting_token_index), classes
  end

  # Do the same thing as #enclose_by_global_character_positions, only using a selection specification
  def enclose_by_selection anchor_path, anchor_offset, focus_path, focus_offset, classes=''
    if anchor_path == focus_path
      anchor_offset, focus_offset = focus_offset, anchor_offset if anchor_offset > focus_offset
      first_te = TextElmtData.new self, anchor_path, anchor_offset
      first_te.enclose_to (first_te.local_to_global focus_offset ), html_enclosure(classes, :span)
      update
    else
      first_te = TextElmtData.new self, anchor_path, anchor_offset
      last_te = TextElmtData.new self, focus_path, focus_offset
      # Need to ensure the selection is in the proper order
      if last_te.elmt_bounds_index < first_te.elmt_bounds_index
        first_te, last_te = last_te, first_te
      end
      # The two elmt datae are marked, ready for enclosing
      enclose_by_text_elmt_data first_te, last_te, classes
    end
  end

  def enclose_by_text_elmt_data teleft, teright, classes=''
    # Remove unselected text from the two text elements and leave remaining text, if any, next door
    teleft.split_left ; teright.split_right
    assemble_tree_from_nodes classes, teleft.text_element, teright.text_element
    update
  end

  # Modify the Nokogiri document to enclose the strings designated by pos_begin and pos_end in a <div> of the given classes
  def enclose_by_global_character_positions global_character_position_start, global_character_position_end, classes = ''
    # Provide a hash of data about the text node that has the token at 'global_character_position_start'
    teleft = text_elmt_data global_character_position_start
    if teleft.encompasses_offset global_character_position_end
      # Both beginning and end are on the same text node
      teleft.enclose_to global_character_position_end, html_enclosure(classes, :span)
      update
    else
      teright = text_elmt_data -(global_character_position_end)
      enclose_by_text_elmt_data teleft, teright, classes
    end
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

  def text_elmt_data global_char_offset
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
  delegate :elmt_bounds, :token_starts, :token_offset_at, :enclose_by_token_indices, :enclose_by_global_character_positions, :text_elmt_data, to: :tokens

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

end

class TextElmtData < Object
  delegate :parent, :text, :'content=', :delete, :ancestors, to: :text_element
  delegate :elmt_bounds, to: :noko_tokens
  attr_accessor :elmt_bounds_index, :text_element, :parent, :local_char_offset
  attr_reader :noko_tokens, :global_start_offset

  def initialize nkt, global_char_offset_or_path, local_offset_mark=0 # character offset (global)
    @noko_tokens = nkt
    @local_char_offset = 0
    if global_char_offset_or_path.is_a? String
      # This is a path/offset specification, so we have to derive the global offset first
      # Find the element from the path
      path_end = nkt.nkdoc.xpath(global_char_offset_or_path.downcase)&.first   # Presumably there's only one match!
      # Linear search: SAD!
      @elmt_bounds_index = elmt_bounds.find_index { |elmt|
        path_end == elmt.first || (path_end.children.include? elmt.first)
      }
      global_char_offset = elmt_bounds[@elmt_bounds_index].last
      signed_global_char_offset = local_offset_mark < 0 ?
                                      (local_offset_mark - global_char_offset) :
                                      (global_char_offset + local_offset_mark)
    else
      signed_global_char_offset = global_char_offset_or_path
    end
    locate_text_element signed_global_char_offset
    @parent = @text_element.parent
  end

  # Get the Nokogiri text element, its global character offset, and its index in the tokens scanner, based on global character offset
  def locate_text_element signed_global_char_offset
    # A negative global character offset denotes a terminating position.
    # Here, we split that into a non-negative global character offset and a 'terminating' flag
    global_char_offset = (terminating = signed_global_char_offset < 0) ? -signed_global_char_offset : signed_global_char_offset
    @elmt_bounds_index = binsearch elmt_bounds, global_char_offset, &:last
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    @elmt_bounds_index -= 1 if terminating && (@elmt_bounds_index > 0) && (elmt_bounds[@elmt_bounds_index].last == global_char_offset)
    @text_element, @global_start_offset = elmt_bounds[@elmt_bounds_index]
    mark_at global_char_offset, terminating
  end

  # Return the Xpath and offset to find the marked token in the document
  def xpath
    csspath = @text_element.css_path
    Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
  end

  # Change the @local_char_offset to reflect a new global offset, which had better be in range of the text
  def mark_at global_char_offset, terminating=false
    token_index = binsearch @noko_tokens.token_starts, global_char_offset
    token_index -= 1 if terminating && (token_index > 0) && (@noko_tokens.token_starts[token_index] == global_char_offset)
    global_char_offset = @noko_tokens.token_starts[token_index]
    # Set the mark at the end of the token if terminating
    global_char_offset += @noko_tokens[token_index].length if terminating
    @local_char_offset = global_to_local global_char_offset
  end

  # Express a local offset in the text element as a global one
  def local_to_global local_offset
    @global_start_offset+local_offset
  end

  def global_to_local global_offset
    global_offset - @global_start_offset
  end

  # Split the text element, insert a new bounds entry and modify self to represent the new node, if any
  def split_left
    return if prior_text.length == 0 # No need to split
    text_element.next = subsq_text
    text_element.content = prior_text
    @global_start_offset += @local_char_offset
    elmt_bounds.insert (@elmt_bounds_index += 1), [(@text_element = text_element.next), @global_start_offset]
    @local_char_offset = 0
  end

  # Split the text element, insert a new bounds entry and modify self to represent the new node, if any
  def split_right
    return if subsq_text.blank? # No need to split
    text_element.previous = prior_text
    text_element.content = subsq_text
    elmt_bounds[@elmt_bounds_index][1] = @global_start_offset + @local_char_offset # Fix existing entry
    elmt_bounds.insert @elmt_bounds_index, [(@text_element = text_element.previous), @global_start_offset]
    @local_char_offset = text.length # Goes to the end of this node
  end

  # Does the text element include the text at the end offset
  def encompasses_offset end_offset
    text_element.text[end_offset - @global_start_offset - 1] != nil
  end

  # Divide an existing text element, splitting off the text between the mark and the given end mark into
  # an element that encloses that text
  def enclose_to global_character_position_end, html
    # Split off a text element for text to the left of the mark (if any such text)
    split_left
    # Split off a text element for text to the right of the limit (if any such text)
    mark_at global_character_position_end, true
    split_right
    # Now add a next element: the html shell
    elmt = text_element
    elmt.next = html
    # Move the element under the shell
    elmt.next.add_child elmt
  end

  # Return the text of the text element prior to the selection point
  def prior_text
    text[0...@local_char_offset]
  end

  # Return the text from the mark to the end of the text element
  def subsq_text mark = @local_char_offset
    text[mark..-1]
  end

  # Return the text from the beginning to the mark (expressed globally)
  def delimited_text mark = nil
    text[mark ? @local_char_offset...(mark-@global_start_offset) : @local_char_offset..-1].strip
  end

  def replace_bound newbounds, text_shrinkage = 0
    elmt_bounds[@elmt_bounds_index..-1].each { |pair| pair[1] -= text_shrinkage } if text_shrinkage != 0
    if newbounds.empty?
      elmt_bounds.delete_at @elmt_bounds_index
    else
      elmt_bounds[@elmt_bounds_index..@elmt_bounds_index] = newbounds
    end
  end

  def remove
    child = text_element
    while (parent = child.parent)
      child.remove
      break if parent.children.count != 0
      child = parent
    end
  end

end
