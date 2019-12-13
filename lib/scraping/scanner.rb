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
  attr_reader :strings, :pos, :length

  def initialize strings, pos = 0
    # We include punctuation and delimiters as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @strings = strings
    @pos = pos
    @length = @strings.count
  end

  def self.from_string string, pos = 0
    self.new tokenize(string), pos
  end

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars = 1
    if @pos < @length
      (nchars == 1) ? @strings[@pos] : @strings[@pos...(@pos + nchars)].join(' ')
    end
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first nchars = 1
    if @pos < @length
      f = @strings[@pos...(@pos + nchars)]&.join(' ')
      @pos += nchars
      @pos = @length if @pos > @length
      f
    end
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars = 1
    newpos = @pos + nchars
    StrScanner.new(@strings, (newpos > @length ? @length : newpos))
  end

  def more?
    @pos < @length
  end

end

class NokoScanner
  attr_reader :pos, :nkdoc, :tokens, :elmt_bounds, :token_starts
  delegate :pp, to: :nkdoc

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc, pos = 0, tokens = nil
    def to_tokens newtext = nil
      # Prepend the string to the priorly held text, if any
      newtext = @held_text + newtext if newtext && @held_text && (@held_text.length > 0)
      @held_text = tokenize((newtext || @held_text), newtext == nil) { |token, offset|
        @tokens.push token
        @token_starts.push @processed_text_len + offset
      }
      @processed_text_len += newtext.length if newtext
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
        @tokens << NokoScanner.new(child)
      when child.element?
        to_tokens "\n" if child.name.match(/^(p|br|li)$/)
        child.children.each { |j| do_child j }
      end
    end

    # Take the parameters as instance variables, creating @tokens if nec.
    @nkdoc = nkdoc
    @pos = pos

    if !(@tokens = tokens)
      @tokens = []
      @elmt_bounds = []
      @token_starts = []
      @processed_text_len = 0
      @held_text = ''
      @nkdoc.children.each { |j| do_child j }
      to_tokens # Finally flush the last text
    end
    @length = @tokens.count
  end

  def self.from_string html
    self.new Nokogiri::HTML.fragment(html)
  end

  # Return the stream of tokens as an array of strings
  def strings
    @tokens.collect { |token| token.is_a?(NokoScanner) ? token.strings : token }.flatten
  end

  def peek nchars = 1
    if @pos < @length
      if nchars == 1
        @tokens[@pos]
      elsif @tokens[@pos...(@pos + nchars)].all? { |token| token.is_a? String } # ONLY IF NO TOKENS
        @tokens[@pos...(@pos + nchars)].join(' ')
      end
    end
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first nchars = 1
    if str = peek(nchars)
      @pos += nchars
      @pos = @length if @pos > @length
    end
    str
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars = 1
    newpos = @pos + nchars
    NokoScanner.new @nkdoc, (newpos > @length ? @length : newpos), @tokens
  end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  def more?
    @pos < @length
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
    html = "<div class='np_elmt #{classes}'></div>" # For constructing the new node
    #  newbounds = []
    if teleft.encompasses_offset pos_end
      # We're in luck! Both beginning and end are on the same text node
      teleft.split_left
      teright = text_elmt_data -(pos_end)
      teright.split_right
      teright.text_element.next = html
      teright.text_element.next.add_child teright.text_element
=begin
      # so we replace the text node with (possibly) two text nodes surrounding the new element
      left_remainder = teleft.prior_text ; right_remainder = teleft.subsq_text pos_end
      newchildren = replace_elmt teleft.text_element,
                                 "#{left_remainder}<div class='np_elmt #{classes}'>#{teleft.delimited_text pos_end}</div>#{right_remainder}"

      # Now we need to adjust the elmt bounds for the
      new_elmt = newchildren.find { |child| child.element? }
      where = teleft.global_start_offset
      if left_remainder.present?
        newbounds << [newchildren.first, where]
        where += left_remainder.length
      end
      newbounds << [new_elmt.children.first, where]
      if right_remainder.present?
        newbounds << [newchildren.last, where+new_elmt.children.first.text.length]
      end
      teleft.replace_bound newbounds, 0 # pos_end-pos_begin-1
=end
    else
      teright = text_elmt_data -(pos_end)
      left_remainder = teleft.prior_text ; right_remainder = teright.subsq_text pos_end
      # Find the common ancestor of the two text nodes
      common_ancestor = (teleft.ancestors & teright.ancestors).first
      left_ancestor = (teleft.ancestors - teright.ancestors).first
      newtree = (left_ancestor.next = html)
      # Remove unselected text from the two text elements and leave adjacent elements next door
      teleft.split_left ; teright.split_right
      # On each side, find the highest parent (up to the common_ancestor) that has no leftward children
      highest_whole_left = teleft.text_element
      while (highest_whole_left.parent != common_ancestor) && !highest_whole_left.previous_sibling do
        highest_whole_left = highest_whole_left.parent
      end
      # Starting with the highest whole node
      elmt = highest_whole_left
      while (elmt != common_ancestor)
        parent = elmt.parent
        while (right_sib = elmt) do
          elmt = right_sib.next
          newtree.add_child right_sib
        end
        elmt = parent
      end

      highest_whole_right = teright.text_element
      while (highest_whole_right.parent != common_ancestor) && !highest_whole_right.next_sibling do
        highest_whole_right = highest_whole_right.parent
      end
      # Starting with the highest whole node
      elmt = highest_whole_right
      while (elmt != common_ancestor)
        parent = elmt.parent
        left_sib = (parent == common_ancestor) ? newtree.next_sibling : parent.children[0]
        while left_sib do
          next_sib = left_sib.next_sibling
          newtree.add_child left_sib
          break if next_sib == elmt
          left_sib = next_sib
        end
        elmt = parent
      end
=begin
      # Capture the elements between the two text elements
      # Capture the text from the first element
      start_html = teleft.subsq_text
      highest_whole_left =
          seek_upwards(teleft.text_element, common_ancestor) do |elmt|
            start_html = elmt.parent.to_s if !elmt.previous_sibling && (elmt.parent != common_ancestor)
          end if (runup_text = teleft.prior_text).blank? && !teleft.text_element.previous_sibling
      x=2
      # For all ancestors of the start node, up to but not including the common ancestor, add their rightmost
      # elements to the enclosure
      left_elmt = seek_upwards((highest_whole_left || teleft.text_element), common_ancestor) do |elmt|
        if elmt.parent != common_ancestor
          while sib = elmt.next_sibling
            start_html << sib.to_s
            sib.remove
          end
          true
        end
      end

      end_html = teright.prior_text

      highest_whole_right = seek_upwards(teright.text_element, common_ancestor) do |elmt|
        end_html = elmt.parent.to_s if !((elmt.parent == common_ancestor) || elmt.next_sibling)
      end if (rundown_text = teright.subsq_text).empty? && !teright.text_element.next_sibling
      x=2
      right_elmt = seek_upwards((highest_whole_right || teright.text_element), common_ancestor) do |elmt|
        # Collect elements to the left
        while (sib = elmt.previous_sibling) && (sib != left_elmt)
          end_html = sib.to_s + end_html
          sib.remove
        end
      end
      # All relevant nodes have been converted to html and deleted
      # All html for the replacement is in start_html + end_html
      # left_elmt is the first relevant child of the common ancestor
      html = "<div class='np_elmt #{classes}'>#{start_html}#{end_html}</div>"
      newelmt =
      case
      when left_elmt == highest_whole_left
        if right_elmt == highest_whole_right
          right_elmt.remove
        elsif !highest_whole_right
          teright.content = rundown_text
        end
        left_elmt.replace html
      when right_elmt == highest_whole_right
        right_elmt.replace html
      else
        # Reset the text of the initial text elements
        teleft.content = runup_text if !highest_whole_left
        teright.content = rundown_text if !highest_whole_right
        left_elmt.next = html
      end
=end
    end
  end

  def text_elmt_data char_offset
    TextElmtData.new self, char_offset
  end

end

class TextElmtData < Object
  delegate :parent, :text, :'content=', :delete, :ancestors, to: :text_element
  delegate :elmt_bounds, to: :noko_scanner
  attr_accessor :elmt_bounds_index, :text_element, :parent
  attr_reader :noko_scanner, :local_char_offset, :global_start_offset

  def initialize nks, global_char_offset # character offset (global)
    global_char_offset = (terminating = global_char_offset < 0) ? (-global_char_offset) : global_char_offset
    @noko_scanner = nks
    @elmt_bounds_index = binsearch elmt_bounds, global_char_offset, &:last
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    @elmt_bounds_index -= 1 if terminating && (@elmt_bounds_index > 0) && (elmt_bounds[@elmt_bounds_index].last == global_char_offset)
    @text_element, @global_start_offset = elmt_bounds[@elmt_bounds_index]
    @local_char_offset = global_char_offset - @global_start_offset
    @parent = @text_element.parent
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

=begin
  # Set the text for the element to 'str'. Delete the element if the text is empty
  def text= str
    if str.present?
      @text_element.text = str
    else
      @text_element.delete
      @text_element = nil
    end
  end
=end
end
