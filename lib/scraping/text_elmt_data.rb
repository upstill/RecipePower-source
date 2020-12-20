require 'scraping/scanner.rb'

# We have to correct character offsets b/c Javascript counts "\r\n" as a single character
# Therefore, every '\r\n' pair prior to an offset should increment the offset.
def correct_selection_offset nominal_offset, text_element
  text_element.to_s.scan(/(?=\r\n)/) do |c|
    if $~.offset(0)[0] < nominal_offset
      nominal_offset += 1
    else
      break
    end
  end
  nominal_offset
end

# TextElmtData manages a Nokogiri TextElement object
class TextElmtData < Object
  delegate :parent, :text, :'content=', :delete, :ancestors, to: :text_element
  attr_accessor :elmt_bounds_index, :parent, :local_char_offset # , :local_char_range
  attr_reader :noko_tokens, :global_start_offset, :elmt_bounds, :text_element

  # Here we initialize a TextElmtData object for a given Nokogiri text element within the document
  # associated with a NokoTokens provider. The text element may be specified in three ways, depending on the
  # class of the first parameter:
  # -- a String denotes a selection path through the document
  # -- a global character offset denotes the element's location within the NokoTokens virtual buffer.
  #     NB: since an offset at the boundary between two text elements is ambiguous, we use a negative offset
  #       to denote the text element prior to the boundary.
  # -- a Nokogiri text element itself.

  # The TextElmtData object emerges from initialization with the following instance variables:
  # @text_element: the Nokogiri text element that we express
  # @local_char_offset: a marker within the text element
  # @global_char_offset: the location of the text element's text within the virtual buffer of NokoTokens
  # @parent: the text element's containing Nokogiri node
  # @elmt_bounds_index: index for this text element in the elmt_bounds array, which pairs each text element with
  #   its global character offset.
  # Note: by definition, @text_element, @global_start_offset == @elmt_bounds[@elmt_bounds_index]
  def initialize elmt_bounds, global_char_offset_or_path_or_text_elmt, local_offset_mark=0 # character offset within the text element
    @elmt_bounds = elmt_bounds
    @local_char_offset = 0
    if global_char_offset_or_path_or_text_elmt.is_a? Integer
      signed_global_char_offset = global_char_offset_or_path_or_text_elmt # Could be signed
    else
      # Derive the text element as necessary
      if global_char_offset_or_path_or_text_elmt.is_a? String
        # This is a path/offset specification, so we have to derive the global offset first
        # Find the element from the path
        text_elmt = elmt_bounds.nkdoc.xpath(global_char_offset_or_path_or_text_elmt.downcase)&.first   # Presumably there's only one match!
        # The selection may end at, e.g., a <p> element; go down to the first text element
        while text_elmt.element?
          text_elmt = text_elmt.children.first
        end
      else
        text_elmt = global_char_offset_or_path_or_text_elmt
      end
      # Linear search: SAD!
      global_char_offset = @elmt_bounds.global_position_of_elmt text_elmt # elmt_bounds.find { |elmt| text_elmt == elmt.first }&.last
      # Split the offset into a positive value and a negative indicator
      local_offset_mark = local_offset_mark.abs if (negatory = local_offset_mark < 0)
      # We have to correct character offsets b/c Javascript counts "\r\n" as a single character
      local_offset_mark = correct_selection_offset local_offset_mark, text_elmt
      signed_global_char_offset = global_char_offset + local_offset_mark
      signed_global_char_offset = -signed_global_char_offset if negatory
    end
    # Get the Nokogiri text element, its global character offset, and its index in the tokens scanner, based on global character offset
    # A negative global character offset denotes a terminating position.
    # Here, we split that into a non-negative global character offset and a 'terminating' flag
    global_char_offset = (terminating = signed_global_char_offset < 0) ? -signed_global_char_offset : signed_global_char_offset
    @elmt_bounds_index = @elmt_bounds.elmt_index_for_position global_char_offset # binsearch elmt_bounds, global_char_offset, &:last
    # The FIRST character of a text element is treated as the LAST character of the previous text element for a terminating offset
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    @elmt_bounds_index -= 1 if (@elmt_bounds_index > 0) && terminating && (@elmt_bounds.elmt_offset_at(@elmt_bounds_index) == global_char_offset)
    @text_element, @global_start_offset =
        @elmt_bounds.nth_elmt(@elmt_bounds_index),
        @elmt_bounds.elmt_offset_at(@elmt_bounds_index) # elmt_bounds[@elmt_bounds_index] # ...by definition
    mark_at signed_global_char_offset
    @parent = @text_element.parent
  end

  # Adopt another text element with its associated information
  def text_element= te
    @elmt_bounds_index = @elmt_bounds.find_elmt_index (@text_element = te)
    @global_start_offset = @elmt_bounds.elmt_offset_at @elmt_bounds_index
    @local_char_offset = 0
    @parent = @text_element.parent
  end

  def self.for_range elmt_bounds, global_character_range
    [
        TextElmtData.new(elmt_bounds, global_character_range.first),
        TextElmtData.new(elmt_bounds, -global_character_range.last)
    ]
  end

  # Return the Xpath and offset to find the marked token in the document
  def xpath
    csspath = @text_element.css_path
    Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
  end

  # Change the @local_char_offset to reflect a new global offset, which had better be in range of the text
  def mark_at signed_global_char_offset
    @local_char_offset = global_to_local signed_global_char_offset.abs
  end

  # Express a local offset in the text element as a global one
  def local_to_global local_offset
    @global_start_offset+local_offset
  end

  def global_char_offset
    local_to_global @local_char_offset
  end

  def global_to_local global_offset
    global_offset - @global_start_offset
  end

  # Split the text element, insert a new bounds entry and modify self to represent the new node, if any
  def split_left *others
    # No need to split at the beginning or end of the text
    return if subsq_text.empty? || prior_text.empty?
    text_element.next = subsq_text
    text_element.content = prior_text
    @global_start_offset += @local_char_offset
    @elmt_bounds.split_elmt_at @elmt_bounds_index, text_element, text_element.next
    @text_element = text_element.next
    @elmt_bounds_index += 1
    @local_char_offset = 0
    # Finally, repair any other TextElmtData objects that might have been affected
    others.
        find_all { |other| other.elmt_bounds_index >= @elmt_bounds_index }.
        each { |other| other.elmt_bounds_index += 1 }
  end

  # Do I come before another?
  def precedes other
    @elmt_bounds_index < other.elmt_bounds_index
  end

  # Split the text element, insert a new bounds entry and modify self to represent the new node, if any
  def split_right *others
    # No need to split at the beginning or end of the text
    return if prior_text.empty? || subsq_text.empty?
    text_element.previous = prior_text
    text_element.content = subsq_text
    @elmt_bounds.split_elmt_at @elmt_bounds_index, text_element.previous, text_element
    @text_element = text_element.previous
    @local_char_offset = text.length # Goes to the end of this node
    # Finally, repair any other TextElmtData objects higher in the array
    others.
        find_all { |other| other.elmt_bounds_index > @elmt_bounds_index }.
        each { |other| other.elmt_bounds_index += 1 }
  end

  # Does the text element include the text at the end offset
  def encompasses_offset end_offset
    text_element.text[end_offset - @global_start_offset - 1] != nil
  end

  # Divide an existing text element, splitting off the text between the mark and the given end mark into
  # an element that encloses that text
  def enclose_to global_character_position_end, classes:, tag: nil, value: nil
    # Split off a text element for text to the left of the mark (if any such text)
    split_left
    # Split off a text element for text to the right of the limit (if any such text)
    mark_at -global_character_position_end
    split_right
    # Now add a next element: the html shell
    elmt = text_element
    elmt.next = html_enclosure tag: tag, classes: classes, value: value
    newnode = elmt.next
    # Move the element under the shell while ensuring that elmt_bounds remains valid
    @elmt_bounds.fix_nth_elmt @elmt_bounds_index, newnode.add_child(elmt)
    @elmt_bounds.fix_nth_elmt @elmt_bounds_index+1, newnode.next if newnode.next&.text?
    validate_embedding newnode
    newnode
  end

  # Return the text of the text element prior to the selection point
  def prior_text
    text[0...@local_char_offset]
  end

  # Return the text from the mark to the end of the text element
  def subsq_text mark = @local_char_offset
    text[mark..-1] || ''
  end

  # Incorporate any preceding blank text to the beginning of the parent.
  # NB: Does not examine any intervening nodes, just checks that they are blank
  def retreat_over_space limit_te=nil
    if prior_text.blank?
      while (text_element != limit_te) && (prev = text_element.previous)&.blank? do
        self.text_element = prev if prev.text?
      end
      mark_at elmt_offset_at(@elmt_bounds_index + 1) # Mark at the end of the element
    end
  end

  # Incorporate any following blank text to the end of the parent
  def advance_over_space limit_te=nil
    if subsq_text.blank?
      while (text_element != limit_te) && (nxt = text_element.next)&.blank? do
        self.text_element = nxt if nxt.text?
      end
      mark_at elmt_offset_at(@elmt_bounds_index + 1) # Mark at the end of the element
    end
  end

  # Return the text from the beginning to the mark (expressed globally)
  def delimited_text mark = nil
    text[mark ? @local_char_offset...(mark-@global_start_offset) : @local_char_offset..-1]&.strip || ''
  end

  def remove
    child = text_element
    while (parent = child.parent)
      child.remove
      break if parent.children.count != 0
      child = parent
    end
  end

  # See if a parent of the current text element has been tagged with a token
  # Returns: the Nokogiri node with that tag that contains the token
  def parent_tagged_with token
    text_element.parent if nknode_has_class?(text_element.parent, token)
  end

  # Does this text element have an ancestor of the given tag, with a class that includes the token?
  def descends_from? tag, token=nil
    text_element.ancestors.find do |ancestor|
      ancestor.name == tag && (token.nil? || nknode_has_class?(ancestor, token))
    end
  end

  def to_s
    text_element.text
  end

end
