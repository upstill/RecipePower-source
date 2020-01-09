require 'string_utils.rb'
require 'binsearch.rb'

# Is the node ready to delete?
def node_empty? nokonode
  return nokonode.text.match /^\n*$/ if nokonode.text? # A text node is empty if all it contains are newlines (if any)
  nokonode.children.blank? || nokonode.children.all? { |child| node_empty? child }
end

# A Scanner object provides a stream of input strings, tokens, previously-parsed entities, and delimiters
# This is an "abstract" class for defining what methods the Scanner provides
class Scanner < Object
  attr_reader :pos

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars = 1

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
      when child.attributes['class']&.value&.match(/\brp_elmt\b/)
        to_tokens
        self << NokoScanner.new(child)
      when child.element?
        to_tokens "\n" if child.name.match(/^(p|br|li)$/)
        child.children.each { |j| do_child j }
      end
    end

    # Take the parameters as instance variables, creating @tokens if nec.
    @nkdoc = nkdoc
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

  def token_offset_at index
    @token_starts[index] || @processed_text_len
  end

  def elmt_offset_at index
    @elmt_bounds[index]&.last || @processed_text_len
  end

  # Convenience method to specify requisite text in terms of tokens
  def enclose_tokens first_token, limiting_token, classes=''
    enclose token_offset_at(first_token), token_offset_at(limiting_token), classes
  end

  # Modify the Nokogiri document to enclose the strings designated by pos_begin and pos_end in a <div> of the given classes
  def enclose pos_begin, pos_end, classes = ''
    def replace_elmt elmt, replacement
      # We enclose all the material in a <span> node, then collapse it
      replacement = "<span>#{replacement}</span>"
      puts "Replacing '#{elmt.text}' with '#{replacement}'."
      parent = elmt.parent
      nodeset = elmt.replace replacement
      newnode = parent.children.find { |child|
        child == nodeset[0]
      }
      newnode.replace newnode.children
    end

    def seek_upwards elmt, limiting_elmt, &block
      while (elmt != limiting_elmt) && block.call(elmt)
        elmt = elmt.parent
      end
      elmt
    end

    # Provide a hash of data about the text node that has the token at 'pos_begin'
    teleft = text_elmt_data pos_begin
    classes = "rp_elmt #{classes}".strip
    html = "<div class='#{classes}'></div>" # For constructing the new node
    #  newbounds = []
    if teleft.encompasses_offset pos_end
      # We're in luck! Both beginning and end are on the same text node
      teleft.split_left
      teleft.mark_at pos_end
      teleft.split_right
      elmt = teleft.text_element
      elmt.next = html
      elmt.next.add_child elmt
    else
      teright = text_elmt_data -(pos_end)
      # Find the common ancestor of the two text nodes
      common_ancestor = (teleft.ancestors & teright.ancestors).first
      left_ancestor = (teleft.text_element if teleft.text_element.parent == common_ancestor) ||
          teleft.ancestors.find { |elmt| elmt.parent == common_ancestor }
      left_ancestor.next = html
      newtree = left_ancestor.next
      # Remove unselected text from the two text elements and leave remaining text, if any, next door
      teleft.split_left ; teright.split_right
      # On each side, find the highest parent (up to the common_ancestor) that has no leftward children
      highest_whole_left = teleft.text_element
      while (highest_whole_left.parent != common_ancestor) && !highest_whole_left.previous_sibling do
        highest_whole_left = highest_whole_left.parent
      end
      # Starting with the highest whole node, add nodes that are included in the selection to the new elmt
      elmt = highest_whole_left.next
      newtree.add_child highest_whole_left
      while (elmt.parent != common_ancestor)
        parent = elmt.parent
        while (right_sib = elmt.next) do
          elmt = right_sib.next
          newtree.add_child right_sib
        end
        elmt = parent
      end

      # Now do the same with the right side, adding preceding elements
      highest_whole_right = teright.text_element
      while (highest_whole_right.parent != common_ancestor) && !highest_whole_right.next_sibling do
        highest_whole_right = highest_whole_right.parent
      end
      # Build a stack from the right node's ancestor below the common ancestor down to the highest whole right node
      stack = [ highest_whole_right ]
      while stack.last.parent != common_ancestor
        stack.push stack.last.parent
      end
      left_sib = newtree.next_sibling
      while ancestor = stack.pop
        while left_sib != ancestor do
          next_sib = left_sib.next_sibling
          newtree.add_child left_sib
          left_sib = next_sib
        end
        left_sib = ancestor.children[0] unless stack.empty?
      end
      newtree.add_child highest_whole_right
    end
    # Because Nokogiri can replace nodes willy-nilly, let's make sure that the elmt_bounds are up to date
    ix = 0
    nkdoc.traverse do |node|
      if node.text?
        @elmt_bounds[ix][0] = node
        ix += 1
      end
    end
  end

  def text_elmt_data char_offset
    TextElmtData.new self, char_offset
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
  delegate :elmt_bounds, :token_starts, :token_offset_at, :enclose_tokens, :enclose, :text_elmt_data, to: :tokens

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc_or_nktokens, pos = 0, bound=nil # length=nil
    # Take the parameters as instance variables, creating @tokens if nec.
    if nkdoc_or_nktokens.class == NokoTokens
      @tokens = nkdoc_or_nktokens
      @nkdoc = nkdoc_or_nktokens.nkdoc
    else
      @nkdoc = nkdoc_or_nktokens
      @tokens = NokoTokens.new nkdoc_or_nktokens
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

  def peek nchars = 1
    if @pos < @bound # @length
      if nchars == 1
        tokens[@pos]
      elsif tokens[@pos...(@pos + nchars)].all? { |token| token.is_a? String } # ONLY IF NO TOKENS
        tokens[@pos...(@pos + nchars)].join(' ')
      end
    end
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
  def first nchars = 1
    if str = peek(nchars)
      @pos += nchars
      @pos = @bound if @pos > @bound # @length if @pos > @length
    end
    str
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars = 1
    newpos = @pos + nchars
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
    @tokens.dom_ranges(str).map do |range|
      NokoScanner.new @tokens, range.begin, range.end
    end
  end

end

class TextElmtData < Object
  delegate :parent, :text, :'content=', :delete, :ancestors, to: :text_element
  delegate :elmt_bounds, to: :noko_tokens
  attr_accessor :elmt_bounds_index, :text_element, :parent
  attr_reader :noko_tokens, :local_char_offset, :global_start_offset

  def initialize nkt, global_char_offset # character offset (global)
    global_char_offset = (terminating = global_char_offset < 0) ? (-global_char_offset) : global_char_offset
    @noko_tokens = nkt
    @elmt_bounds_index = binsearch elmt_bounds, global_char_offset, &:last
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    @elmt_bounds_index -= 1 if terminating && (@elmt_bounds_index > 0) && (elmt_bounds[@elmt_bounds_index].last == global_char_offset)
    @text_element, @global_start_offset = elmt_bounds[@elmt_bounds_index]
    mark_at global_char_offset
    @parent = @text_element.parent
  end

  # Change the @local_char_offset to reflect a new global offset, which had better be in range of the text
  def mark_at offset
    @local_char_offset = offset - @global_start_offset
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
    return if subsq_text.length == 0 # No need to split
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

  # Return the text of the text element prior to the selection point
  def prior_text
    text[0...@local_char_offset]
  end

  # Return the text from the mark to the end of the text element
  def subsq_text mark = @local_char_offset
    text[mark..-1]
  end

  def delimited_text mark = nil
    text[mark ? @local_char_offset...mark : @local_char_offset..-1]
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
