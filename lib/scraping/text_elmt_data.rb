require 'scraping/scanner.rb'

def nknode_has_class? node, css_class
  node['class']&.split&.include?(css_class.to_s) if node
end

def nknode_add_classes node, css_classes
  absent = css_classes.split.collect { |css_class|
    css_class unless nknode_has_class? node, css_class
  }.compact.join(' ')
  node['class'] = "#{node['class']} #{absent}"
end

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
  delegate :elmt_bounds, :token_index_for, :to_token_bound, :valid_mark?, to: :noko_tokens
  attr_accessor :elmt_bounds_index, :text_element, :parent, :local_char_offset # , :local_char_range
  attr_reader :noko_tokens, :global_start_offset

  def initialize nkt, global_char_offset_or_path, local_offset_mark=0 # character offset within the text element
    @noko_tokens = nkt
    @local_char_offset = 0
    if global_char_offset_or_path.is_a? String
      # This is a path/offset specification, so we have to derive the global offset first
      # Find the element from the path
      path_end = nkt.nkdoc.xpath(global_char_offset_or_path.downcase)&.first   # Presumably there's only one match!
      # Linear search: SAD!
      global_char_offset = elmt_bounds.find { |elmt| path_end == elmt.first }.last
      # Split the offset into a positive value and a negative indicator
      local_offset_mark = local_offset_mark.abs if (negatory = local_offset_mark < 0)
      # We have to correct character offsets b/c Javascript counts "\r\n" as a single character
      local_offset_mark = correct_selection_offset local_offset_mark, path_end
      signed_global_char_offset = global_char_offset + local_offset_mark
      signed_global_char_offset = -signed_global_char_offset if negatory
    else
      signed_global_char_offset = global_char_offset_or_path # Could be signed
    end
    locate_text_element signed_global_char_offset
    @parent = @text_element.parent
  end

  # Get the Nokogiri text element, its global character offset, and its index in the tokens scanner, based on global character offset
  def locate_text_element signed_global_char_offset
    # Ensure that the pointer does not violate token boundaries
    signed_global_char_offset = to_token_bound signed_global_char_offset
    # A negative global character offset denotes a terminating position.
    # Here, we split that into a non-negative global character offset and a 'terminating' flag
    global_char_offset = (terminating = signed_global_char_offset < 0) ? -signed_global_char_offset : signed_global_char_offset
    @elmt_bounds_index = binsearch elmt_bounds, global_char_offset, &:last
=begin
    if !@elmt_bounds_index = binsearch(elmt_bounds, global_char_offset, &:last)
      # Too low (before the first text element)
      @elmt_bounds_index = 0
      signed_global_char_offset = elmt_bounds[0].last
    end
=end
    # The FIRST character of a text element is treated as the LAST character of the previous text element for a terminating offset
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    @elmt_bounds_index -= 1 if (@elmt_bounds_index > 0) && terminating && (elmt_bounds[@elmt_bounds_index].last == global_char_offset)
    @text_element, @global_start_offset = elmt_bounds[@elmt_bounds_index]
    mark_at signed_global_char_offset
  end

  def self.for_range nkt, global_character_range
    [ TextElmtData.new(nkt, global_character_range.first), TextElmtData.new(nkt, -global_character_range.last) ]
  end

  # Return the Xpath and offset to find the marked token in the document
  def xpath
    csspath = @text_element.css_path
    Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
  end

  # Change the @local_char_offset to reflect a new global offset, which had better be in range of the text
  def mark_at signed_global_char_offset
    @local_char_offset = global_to_local to_token_bound(signed_global_char_offset).abs
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
    # No need to split at the beginning or end of the text
    return if subsq_text.empty? || prior_text.empty?
    text_element.next = subsq_text
    text_element.content = prior_text
    @global_start_offset += @local_char_offset
    elmt_bounds.insert (@elmt_bounds_index += 1), [(@text_element = text_element.next), @global_start_offset]
    @local_char_offset = 0
  end

  # Split the text element, insert a new bounds entry and modify self to represent the new node, if any
  def split_right
    # No need to split at the beginning or end of the text
    return if prior_text.empty? || subsq_text.empty?
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
    mark_at -global_character_position_end
    split_right
    # Now add a next element: the html shell
    elmt = text_element
    elmt.next = html
    newnode = elmt.next
    # Move the element under the shell
    elmt.next.add_child elmt
    validate_embedding newnode
  end

  # Return the text of the text element prior to the selection point
  def prior_text
    text[0...@local_char_offset]
  end

  # Return the text from the mark to the end of the text element
  def subsq_text mark = @local_char_offset
    text[mark..-1] || ''
  end

  # Return the text from the beginning to the mark (expressed globally)
  def delimited_text mark = nil
    text[mark ? @local_char_offset...(mark-@global_start_offset) : @local_char_offset..-1]&.strip || ''
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

  # See if a parent of the current text element has been tagged with a token
  # Returns: the Nokogiri node with that tag that contains the token
  def parent_tagged_with token
    text_element.parent if nknode_has_class?(text_element.parent, token)
  end

  # Does this text element have an ancestor of the given tag, with a class that includes the token?
  def descends_from? tag, token
    text_element.ancestors.find do |ancestor|
      ancestor.name == tag && nknode_has_class?(ancestor, token)
    end
  end

  def to_s
    text_element.text
  end

end
