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
    ebx = @elmt_bounds.elmt_index_for_position global_char_offset # binsearch elmt_bounds, global_char_offset, &:last
    # The FIRST character of a text element is treated as the LAST character of the previous text element for a terminating offset
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    ebx -= 1 if (ebx > 0) && terminating && (@elmt_bounds.elmt_offset_at(ebx) == global_char_offset)
    assign_to_nth_elmt ebx, signed_global_char_offset
  end

  # Assign a different text element by index
  def assign_to_nth_elmt at_index, signed_global_char_offset=local_to_global(@local_char_offset || 0)
    return nil unless @elmt_bounds[at_index]
    @elmt_bounds_index = at_index
    @text_element, @global_start_offset =
        @elmt_bounds.nth_elmt(@elmt_bounds_index),
            @elmt_bounds.elmt_offset_at(@elmt_bounds_index)
    mark_at signed_global_char_offset #   @local_char_offset = 0
    @parent = @text_element.parent
    @elmt_bounds.text_element_valid? @text_element # Validate that the associated text element hasn't been replaced in the document tree
  end

  # Adopt another text element with its associated information
  def text_element= te
    assign_to_nth_elmt @elmt_bounds.find_elmt_index(te)
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

  # Do I come before another?
  def precedes other
    @elmt_bounds_index < other.elmt_bounds_index
  end

  # Split the text element, insert a new bounds entry and modify self to represent the new node, if any
  # -- and_advance: when true, the ted advances to the next text element
  def split and_advance:
    # No need to split at the beginning or end of the text
    return if subsq_text.empty? || prior_text.empty?
    # Split the text element at the local marker
    text_element.next = subsq_text
    text_element.content = prior_text
    @elmt_bounds.split_elmt_at @elmt_bounds_index, text_element, text_element.next
    @elmt_bounds_index += 1 if and_advance
    assign_to_nth_elmt @elmt_bounds_index
    valid?
    yield(1) if block_given? # Report back an adjustment in @elmt_bounds
  end

  # Split the ancestor shared with 'other'
  def split_common other
    common_ancestor = (@text_element.ancestors & other.text_element.ancestors).first
    # Split the ancestor before and after the selected text, as necessary
    # We'll need to update @elmt_bounds appropriately
    fixture = nknode_first_text_element common_ancestor.parent
    fixture_index = @elmt_bounds.find_elmt_index fixture
    common_ancestor = nknode_split_ancestor_of @text_element, other.text_element
    # The element index of the first text element of the common ancestor's parent should be unchanged
    @elmt_bounds.update_for common_ancestor, nknode_first_text_element(common_ancestor), fixture_index
    # Refresh the TextElementDatas from the elmt_bounds
    assign_to_nth_elmt @elmt_bounds_index
    other.assign_to_nth_elmt other.elmt_bounds_index # Refresh the other text element
    common_ancestor
  end

  # Split the text element's parent in two, inserting the text element between the two
=begin
  def split_parent
    p = text_element.parent
    gp = p.parent
    if text_element.previous.nil?
      # The first element in the parent: simply make it the parent's rightmost sibling
      p.previous = text_element
      newte = p.previous
    elsif text_element.next.nil?
      # The last element in the parent: simply make it the parent's rightmost sibling
      p.next = text_element
      newte = p.next
    else
      # Worst case scenario: there is material before and after the text
      # Split the parent at the te's index
      ix = p.children.index text_element
      pix = gp.children.index p # Index of the parent in ITS parent
      p.next = p.document.create_element(p.name)
      to_move = p.children[(ix+1)..-1]
      to_move.remove
      p.next << to_move
      p.next = text_element
      newte = p.next
    end
    if newte.object_id != text_element.object_id
      # Since the associated text_element has changed, we need to fix @elmt_bounds
      @text_element = newte
      @elmt_bounds.update_for gp, newte, @elmt_bounds_index
      if newte.object_id != text_element.object_id
        x=2
      end
    end
  end
=end

  # Is this TextElementData instance still a valid representation of a node in the document?
  def valid?
    return false unless nknode_valid?(@text_element)
    begin
      throw "TextElmtData no longer has place in @elmt_bounds" unless @elmt_bounds[@elmt_bounds_index].first == @text_element
      if predecessor = @elmt_bounds[@elmt_bounds_index-1]&.first
        throw "TextElmtData's predecessor in @elmt_bounds is invalid" unless nknode_valid?(predecessor)
      end
      if successor = @elmt_bounds[@elmt_bounds_index+1]&.first
        throw "TextElmtData's successor in @elmt_bounds is invalid" unless nknode_valid?(successor)
      end
    rescue Exception => exc
      return false
    end
    true
  end

  # Does the text element include the text at the end offset
  def encompasses_offset end_offset
    text_element.text[end_offset - @global_start_offset - 1] != nil
  end

  # Divide an existing text element, splitting off the text between the mark and the given end mark into
  # an element that encloses that text
  def enclose_to global_character_position_end, rp_elmt_class:, tag: nil, value: nil
    # Split off a text element for text to the left of the mark (if any such text)
    split and_advance: true  # Shed the prior text into a new text element
    # Split off a text element for text to the right of the limit (if any such text)
    mark_at -global_character_position_end
    split and_advance: false # Shed the subsq text into a new text element
    while nknode_has_illegal_enclosure?(self, tag) do
      split_common self # split_parent
    end
    # Now add a next element: the html shell
    @text_element.next = html_enclosure tag: tag, rp_elmt_class: rp_elmt_class, value: value
    newnode = @text_element.next
    newnode.add_child(@text_element)
    @text_element = newnode.children.first
    # Move the element under the shell while ensuring that elmt_bounds remains valid
    @elmt_bounds.replace_nth_element @elmt_bounds_index, @text_element
    @elmt_bounds.replace_nth_element @elmt_bounds_index+1, newnode.next if newnode.next&.text?
    valid?
    # validate_embedding newnode
    newnode
  end

  # Return the text of the text element prior to the selection point
  # If a Nokogiri node is provided as 'within', include the text of earlier text elements under that node
  def prior_text within: nil
    before = text[0...@local_char_offset]
    within ? (nknode_text_before(@text_element, within: within) + before) : before
  end

  # Return the text from the mark to the end of the text element
  # If a Nokogiri node is provided as 'within', include the text of later text elements under that node
  def subsq_text mark = @local_char_offset, within: nil
    after = text[mark..-1] || ''
    within ? (after + nknode_text_after(@text_element, within: within)) : after
  end

  def retreat_over_space limit_te=nil
    # Move the local_char_offset past whitespace
    while (nblanks = prior_text.match(/[[:space:]]*\z/)[0].length) > 0 || prior_text.empty? do
      @local_char_offset -= nblanks
      break if text_element == limit_te
      if prior_text.empty? # If, after eliding spaces, there's nothing else, go to the prior text elmt, if any
        # Adopt the previous text element
        break if !(assign_to_nth_elmt @elmt_bounds_index-1) # End of the line!
      end
    end
  end

  def advance_over_space limit_te=nil
    # Move the local_char_offset past whitespace
    while (nblanks = subsq_text.match(/\A[[:space:]]*/)[0].length) > 0 || subsq_text.empty? do
      @local_char_offset += nblanks
      break if text_element == limit_te
      if subsq_text.empty? # If, after eliding spaces, there's nothing else, go to the next text elmt, if any
        # Adopt the subsequent text element
        break if !(assign_to_nth_elmt @elmt_bounds_index+1) # End of the line!
      end
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

  def to_s
    text_element.text[0...@local_char_offset] + '|' + text_element.text[@local_char_offset..-1]
  end

end
