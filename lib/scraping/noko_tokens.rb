require 'binsearch.rb'
require 'scraping/text_elmt_data.rb'

# This class analyzes and represents tokens within a Nokogiri doc.
# Once defined, it (but not the doc) is immutable
class NokoTokens < Array
  attr_reader :nkdoc, :elmt_bounds, :token_starts, :bound # :length
  delegate :pp, :to => :nkdoc
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
        # to_tokens "\n" if child.name.match(/^(p|br)$/)
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
    global_character_position_start = token_offset_at first_token_index
    global_character_position_end = token_limit_at limiting_token_index
    # Provide a hash of data about the text node that has the token at 'global_character_position_start'
    teleft, teright = TextElmtData.for_range self, global_character_position_start...global_character_position_end
    if teleft.text_element == teright.text_element
      # Both beginning and end are on the same text node
      # Either add the specified class to the parent, or enclose the selected text in a new span element
      # If the enclosed text is all alone in a span, just add to the classes of the span
      if teleft.parent.name == (options[:tag].to_s || 'span') &&
          options[:classes] &&
          !teleft.prior_text.present? &&
          !teright.subsq_text.present? &&
          teleft.parent.children.count == 1
        teleft.parent[:class] = "#{teleft.parent[:class]} #{options[:classes]}" unless teleft.parent[:class].split.include?(options[:classes].to_s)
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
      # When preceding and succeeding text is blank, and we can use an enclosing <span>, just mark it
      unless first_te.text[0...anchor_offset].blank? &&
          first_te.text[focus_offset...-1].blank? &&
        newnode = tag_ancestor(first_te.parent, first_te.text_element, first_te.text_element, (options[:tag]&.to_s || 'span'), options[:classes])
        newnode = first_te.enclose_to (first_te.local_to_global focus_offset ), html_enclosure({tag: :span}.merge options)
        update
      end
    else
      first_te = TextElmtData.new self, anchor_path, anchor_offset
      last_te = TextElmtData.new self, focus_path, -focus_offset
      # Need to ensure the selection is in the proper order
      if last_te.elmt_bounds_index < first_te.elmt_bounds_index
        first_te = TextElmtData.new self, focus_path, focus_offset
        last_te = TextElmtData.new self, anchor_path, -anchor_offset
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
    newnode = assemble_tree_from_nodes teleft.text_element, teright.text_element, options
    update
    newnode
  end

  # What is the index of the token that includes the given offset (where negative offset denotes a terminating location)
  def token_index_for signed_global_char_offset
    global_char_offset = (terminating = signed_global_char_offset < 0) ? -signed_global_char_offset : signed_global_char_offset
    token_ix = binsearch token_starts, global_char_offset
    if terminating
    # A terminating mark at the beginning of a token is interpreted at the end of the prior token
      return token_ix-1 if token_starts[token_ix] == global_char_offset && token_ix > 0
    else
      # A beginning mark at the end of a token (or after) is interpreted at the beginning of the next token
      return token_ix+1 if global_char_offset >= (token_starts[token_ix] + self[token_ix].length)
    end
    token_ix
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
  def dom_range selector_or_node
    return unless node = selector_or_node.is_a?(String) ? nkdoc.search(selector_or_node).first : selector_or_node
    range_from_subtree node
  end

  # Do the above but for EVERY match on the DOM. Returns a possibly empty array of values
  def dom_ranges selector
    nkdoc.search(selector)&.map do |found|
      range_from_subtree found
    end || []
  end

  def range_from_subtree node
    first_text_element = nil
    last_text_element = nil
    node.traverse do |child|
      if child.text?
        last_text_element = child
        first_text_element ||= child
      end
    end
    first_text_element ||= successor_text @nkdoc, node # The node has no text elements, perhaps because it's a <br> tag. Return an empty range for the next text element
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
    if last_limit
      last_token_index = binsearch @token_starts, last_limit # The last token is a limit
      last_token_index += 1 if (token_offset_at(last_token_index)+self[last_token_index].length) <= last_limit # Increment if token is entirely w/in the element
      return first_token_index...last_token_index
    else
      return first_token_index..first_token_index
    end
  end
end
