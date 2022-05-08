require 'binsearch.rb'
require 'scraping/text_elmt_data.rb'
require 'scraping/dom_traversor.rb'
require 'scraping/elmt_bounds.rb'
module Bracket

  # Cycle through the lines in a document, defined as non-empty streams of tokens bounded by newline, <br> or EOF
  # range brackets the relevant tokens
  def for_lines range: nil, inline: true, &block
    bound = range.end
    results = []
    # @brs is a memoized list of locations of linebreaks (either <br> elements or newlines)
    brix = binsearch @brs, range.begin # This is the bin containing the current pos
    brix += 1 unless @brs[brix] == range.begin
    # Now brix denotes the index in the @brs array of the token position (brpos) of the next <br>
    while (pos = @brs[brix]) < range.end do
      # Otherwise, we know we have at least one non-EOL character
      # Find the position of the next EOL, or the end of the buffer, or the position of the next <br> directive
      # If :inline, truncate at the next EOL character
      bound = @brs[brix + 1] if inline
      results << yield(pos, bound)
      brix += 1
    end
    results
  end
end

class StringTokens < Array
  include Bracket
  def initialize text
    @token_starts = []
    # @brs gives the token location of effective EOLs (newlines or <br> elements)
    @brs = [0] # There's an implicit one at the stream's beginning
    tokenize(text, true) { |token, offset|
      # Newlines are reported as tokens, but we put them into the brs map instead of the token array
      if token == "\n"
        next if last == "\n" # No repetitive EOLs, please
        # Instead of pushing the newline as a token, add it to @brs
        @brs.push length
      else
        push token
      end
    }
    @brs.push length # There's an implicit linebreak at the end of the token stream
    @bound = count

    # Make this data immutable! No transforms to the tree should affect any token
    @brs.uniq!.freeze # Freeze the brs array
    self.map &:freeze # Freeze each string
    self.freeze
  end

end

# This class analyzes and represents tokens within a Nokogiri doc.
# Once defined, it (but not the doc) is immutable
class NokoTokens < Array
  include Bracket  # Extend with #for_lines method

  attr_reader :nkdoc, :elmt_bounds, :token_starts, :bound # :length
  delegate :pp, :to => :nkdoc
  def initialize nkdoc
    def to_tokens newtext = nil
      # Append the string to the priorly held text, if any
      if newtext
        newtext = @held_text + newtext if @held_text && (@held_text.length > 0)
      else
        held_len = @held_text.length
      end
      @held_text = tokenize((newtext || @held_text), newtext == nil) { |token, offset|
        # Newlines are reported as tokens, but we put them into the brs map instead of the token array
        if token == "\n" # && (last == token)
          next if last == "\n" # No repetitive EOLs, please
          # Instead of pushing the newline as a token, add it to @brs
          @brs.push @token_starts.length
        else
          push token
          @token_starts.push @processed_text_len + offset
        end
      }
      @processed_text_len += newtext&.length || held_len
      @processed_text_len -= @held_text.length
    end

    def do_child child
      case
      when child.text?
        # Save this element and its starting point
        # @elmt_bounds.push child, (@processed_text_len + @held_text.length) # @elmt_bounds << [child, (@processed_text_len + @held_text.length)]
        to_tokens child.text
      when child.element?
        # Flush token except when entering a span
        to_tokens unless child.name == 'span' # if child.name.match(/^(p|br|ul|li)$/)
        @brs.push @token_starts.length if child.name == 'br'
        child.children.each { |j| do_child j }
      end
    end

    # Take the parameters as instance variables, creating @tokens if nec.
    @nkdoc = nkdoc.is_a?(String) ? Nokogiri::HTML.fragment(nkdoc) : nkdoc
    @elmt_bounds = ElmtBounds.new nkdoc
    @token_starts = []
    # @brs gives the token location of effective EOLs (newlines or <br> elements)
    @brs = [0] # There's an implicit one at the stream's beginning
    @processed_text_len = 0
    @held_text = ''
    @nkdoc.children.each { |j| do_child j }
    to_tokens # Finally flush the last text

    # Make this data immutable! No transforms to the tree should affect any token
    @token_starts.freeze
    @brs.push @token_starts.length # There's an implicit linebreak at the end of the token stream
    @brs.uniq!.freeze
    self.map &:freeze
    @bound = count
    @parser_evaluator = ParserEvaluator.new
    @parser_evaluator.can_include :rp_instructions, :rp_inglist
    @caches = [ { text_element: nil, enclosing_classes: nil } ]
    self.freeze
  end

  def character_position_at_token token_index
    @token_starts[token_index] || @processed_text_len
  end

  # What's the global character offset at the END of the token before the limiting token?
  def character_position_after_token token_limit_index
    return 0 if token_limit_index == 0
    character_position_at_token(token_limit_index-1) + self[token_limit_index-1].length
  end

  # Moving nodes under a parent, we have to be careful to maintain the integrity of
  # 1) the hierarchy of elements (i.e., :rp_ingline under :rp_inglist), and
  # 2) the elements index, because Nokogiri will merge two succeeding text elements into one child
  # Parameters:
  # attach: how to place incoming nodes relative to the parent
  # -- before: add as previous sibling
  # -- after:  add as next sibling
  # -- extend_left: insert as first child
  # -- extend_right: insert as last child
  # return: the node as added to the parent (may change if text elements are merged)
  def move_elements_safely attach: :extend_right, relative_to:, iterator:
    # Find the lowest enclosing RP class of the parent
    enclosing_classes = ([relative_to] + relative_to.ancestors).
        to_a.inject(nil) { |memo, node| memo ||= nknode_rp_classes(node).if_present }

    # The iterator produces a series of nodes, which we add to relative_to, after processing
    iterator.walk do |node|
      next if node == relative_to
      processed_children(node, reversed: attach == :extend_left) { |descendant|
        enclosing_classes.blank? || @parser_evaluator.can_include?(enclosing_classes.first, nknode_rp_classes(descendant).first)
      }.each do |descendant|
        elmt_bounds.attach_node_safely descendant, relative_to, attach
      end
    end
    elmt_bounds.text_element_valid? relative_to.parent
  end

  # Return the string representing all the text given by the two token positions
  # NB This is NOT the space-separated join of all tokens in the range, b/c any intervening whitespace is not collapsed
  def text_from first_token_index, limiting_token_index
    pos_begin = character_position_at_token first_token_index
    pos_end = character_position_after_token limiting_token_index
    return '' if first_token_index >= limiting_token_index || pos_begin == @processed_text_len # Boundary condition: no more text!

    teleft, teright = TextElmtData.for_range @elmt_bounds, pos_begin...pos_end
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

  ###### The following methods pertain to rearranging a DOM to enclose selected text within a marking element

  # Convenience method to specify requisite text in terms of tokens
  def enclose_tokens first_token_index, limiting_token_index, tag: 'span', rp_elmt_class: nil, value: nil, strict: true
    stripped_text = text_from(first_token_index, limiting_token_index).strip
    return if stripped_text.blank?
    global_character_position_start = character_position_at_token first_token_index
    global_character_position_end = character_position_after_token limiting_token_index
    # Provide a hash of data about the text node that has the token at 'global_character_position_start'
    teleft, teright = TextElmtData.for_range @elmt_bounds, global_character_position_start...global_character_position_end
    enclose_by_text_elmt_data teleft, teright, tag: tag, rp_elmt_class: rp_elmt_class, value: value, strict: strict
  end

  # Return the Nokogiri node that was built
  def enclose_selection anchor_path, anchor_offset, focus_path, focus_offset, tag: 'span', rp_elmt_class: nil, value: nil
    if anchor_path == focus_path && anchor_offset > focus_offset
      anchor_offset, focus_offset = focus_offset, anchor_offset
    end
    first_te = TextElmtData.new elmt_bounds, anchor_path, anchor_offset
    last_te = TextElmtData.new elmt_bounds, focus_path, -focus_offset
    # Need to ensure the selection is in the proper order
    if last_te.precedes first_te
      first_te = TextElmtData.new elmt_bounds, focus_path, focus_offset
      last_te = TextElmtData.new elmt_bounds, anchor_path, -anchor_offset
    end
    # The two elmt data are marked, ready for enclosing
    enclose_by_text_elmt_data first_te, last_te, tag: tag, rp_elmt_class: rp_elmt_class, value: value
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
    return TextElmtData.for_range(@elmt_bounds, global_range)
  end

  # Extract the text element data for the character "at" the given global position.
  def text_elmt_data token_index
    if token_index < 0
      TextElmtData.new @elmt_bounds, -character_position_at_token(-token_index)
    else
      TextElmtData.new @elmt_bounds, character_position_at_token(token_index)
    end
  end

  # Extract all :rp_* classes that have been applied to ancestors of the text element at token 'token_index'
  def enclosing_classes_at token_index
    # We cache the vts array for a given text element, in the expectation of being called more than once
    return [] unless (ted = text_elmt_data(token_index)) && (text_element = ted.text_element)
    cache = @caches.first
    return cache[:enclosing_classes] if text_element == cache[:text_element]
    cache[:enclosing_classes] = nknode_enclosing_classes (cache[:text_element] = text_element)
  end

  # Provide the token range enclosed by the CSS selector
  # RETURNS: if found, a Range value denoting the first token offset and token limit in the DOM.
  # If not found, nil
  # NB If a block is given, return the result of that block, called on the range and associated DOM element
  def dom_range selector_or_node
    return unless node = selector_or_node.is_a?(String) ? nkdoc.search(*CSSExtender.args(selector_or_node)).first : selector_or_node
    block_given? ? yield(token_range_for_subtree(node), node) : token_range_for_subtree(node)
  end

  # Do the above but for EVERY match on the DOM. Returns a possibly empty array of values
    # If there is a block given, collect and return the results from that block
  # Otherwise, simply collect matching DOM ranges and return that set
  def dom_ranges spec
    flag, selector = spec.to_a.first # Fetch the key and value from the spec
    pairs = nkdoc.search(*CSSExtender.args(selector))&.map do |found|
      [token_range_for_subtree(found), found]
    end || []
    # We could be working from a Nokogiri element (as opposed to a whole document).
    # In that case, check that the element itself matches the selector, and include it if so
    pairs << [token_range_for_subtree(nkdoc), nkdoc] if nkdoc.parent && nkdoc.matches?(*CSSExtender.args(selector))
    # For :at_css_match, pairs[i] runs to the beginning of pairs[i+1]
    results = []
    while pair = pairs.shift do
      range, nokonode = pair
      # First thing, eliminate subsequent overlapping ranges
      while pairs.present? && range.include?(pairs.first.first) do
        pairs.shift
      end
      min, max = range.begin, range.end
      if flag == :at_css_match && (next_range = pairs.first&.first)
        # Limit the range of this match to the beginning of the next
        max = next_range.begin || @bound
      end
      while min < @bound && self[min].blank? do min += 1 end
      range = (max > min ? min..max : min...min)
      results.push ((flag == :in_css_match) && block_given?) ?
                       yield(range, nokonode) :
                       range
    end
    results
  end

  # What are the tokens for encompassing the given subtree?
  # Returns: a Range giving those indices in @token_starts
  def token_range_for_subtree node
    first_text_element = nil
    last_text_element = nil
    # Traverse the node tree in search of the first and last text elements
    node.traverse do |child|
      if child.text?
        last_text_element = child
        first_text_element ||= child
      end
    end
    token_range_for_text_elements first_text_element || nknode_successor_text_elmt( @nkdoc, node), 
                                  last_text_element
  end

  # What are the tokens for the document between two text elements?
  # Returns: a Range giving those indices in @token_starts
  def token_range_for_text_elements first_text_element, last_text_element
    # By convention, a nil first element means an empty token range past the range of tokens
    return @token_starts.count...@token_starts.count if first_text_element.nil?

    first_pos, last_limit = @elmt_bounds.range_encompassing first_text_element, last_text_element
    # Now we have an index in the elmts array, but we need a range in the tokens array.
    # Fortunately, that is sorted by index, so: binsearch!
    first_token_index = binsearch(@token_starts, first_pos) || 0 # Find the token at this position
    first_token_index += 1 if character_position_at_token(first_token_index) < first_pos # Round up if the token overlaps the boundary
    if last_limit
      last_token_index = binsearch @token_starts, last_limit # The last token is a limit
      last_token_index += 1 if (character_position_at_token(last_token_index)+self[last_token_index].length) <= last_limit # Increment if token is entirely w/in the element
      first_token_index...last_token_index
    else
      first_token_index...first_token_index
    end
  end

  private

  # This is the main method for rearranging text in the DOM, enclosing
  # the text denoted by TextElmtData entities teleft and teright IN THEIR ENTIRETY.
  def enclose_by_text_elmt_data teleft, teright, rp_elmt_class:, tag: 'span', value: nil, strict: true
    # Ignore blank text outside the range
    teleft.advance_over_space teright # Don't pass through each other!
    teright.retreat_over_space teleft
    # Now teleft should be empty before its mark
    # and teright should be empty after its mark
    anchor_elmt, focus_elmt = [teleft, teright].map &:text_element
    common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first

    # Report on situation
    if Rails.env.test?
      puts "\n---------------------\nEnclosing from '#{teleft.to_s}' to '#{teright.to_s}' in #{tag}.#{rp_elmt_class} within: ", pretty_indented_html(common_ancestor.to_s)
    end

    # Check that an existing ancestor can be tagged
    if teleft.prior_text.blank? && # no meaningful text before the leftmost mark
        teright.subsq_text.blank? # ...or after the rightmost mark
      newnode = tag_ancestor_safely(common_ancestor,
                                    anchor_elmt,
                                    focus_elmt,
                                    tag: tag,
                                    rp_elmt_class: rp_elmt_class,
                                    value: value,
                                    parser_evaluator: @parser_evaluator)
      newnode ||=
      if anchor_elmt == focus_elmt
        # #enclose_to does its own validation
        teleft.enclose_to(teright.global_char_offset, tag: tag, rp_elmt_class: rp_elmt_class, value: value)
      elsif teleft.prior_text(within: common_ancestor).blank? && teright.subsq_text(within: common_ancestor).blank?
        # If we're at the top level, we need to enclose every element under a new element
        children = common_ancestor.children
        nn = common_ancestor.add_child(html_enclosure tag: tag, rp_elmt_class: rp_elmt_class, value: value).first
        @elmt_bounds.attach_nodes_safely children, nn
        nn
      end
      if newnode
        puts "After enclosure:", pretty_indented_html(common_ancestor.to_s), '--------------------------------------' if Rails.env.test?
        return newnode
      end
    end

    # Remove unselected text from the two text elements and leave remaining text, if any,
    # before teleft and after teright
    teleft.split(and_advance: true) { |nelmts_inserted| teright.assign_to_nth_elmt(teright.elmt_bounds_index + nelmts_inserted) }
    teright.split and_advance: false # Note the assumption that teleft will be unaffected by teright splitting

    # If teleft or teright are descendants of a node that matches the tag and class spec,
    # we expand that node to encompass the whole selection IF the strict flag is set
    if rp_elmt_class && strict
      selector = "#{tag || 'span'}.#{rp_elmt_class}"
      # If the strict flag is set, find ancestors of the bracketing text elements that are already tagged as specified
      extant_right, extant_left =
          (teright.ancestors & nkdoc.css(*CSSExtender.args(selector))).first,
              (teleft.ancestors & nkdoc.css(*CSSExtender.args(selector))).first
      if extant_left || extant_right
        if extant_right == extant_left
          # The selection is entirely under the requisite node => move OTHER (preceding and succeeding) content out
          # For lack of a better place, we'll move it all before and after the extant node
          move_elements_safely attach: :before, relative_to: extant_left, iterator: DomTraversor.new(teleft.text_element, extant_left, :left)
          move_elements_safely attach: :after, relative_to: extant_left, iterator: DomTraversor.new(extant_left, teright.text_element, :right)
          return extant_left
        elsif extant_left
          move_elements_safely attach: :extend_right, relative_to: extant_left, iterator: DomTraversor.new(extant_left, teright.text_element, :enclosed)
          return extant_left
          # Same procedure if the end of the selection has a viable ancestor
        elsif extant_right
          move_elements_safely attach: :extend_left, relative_to: extant_right, iterator: DomTraversor.new(teleft.text_element, extant_right, :enclosed_reversed)
          # Append selection not already in the extant tree to it
          return extant_right
        end
      end
      # If there is an extant node, tagged compatibly, embedded somewhere else within the range,
      # move everything to that node, proceeding as though it serves as BOTH extant_left and extant_right
      # Search for a set of extant nodes in the tree that are suitably tagged
      extant_candidates = nil
      DomTraversor.new(teleft.text_element, teright.text_element, :enclosed_reversed).walk do |node|
        extant_candidates = extant_candidates ? (extant_candidates + node.css(*CSSExtender.args(selector))) : node.css(*CSSExtender.args(selector))
      end
      if extant = extant_candidates.first
        # We've identified a node on which we can hang selected elements.
        # Ensure that we don't try to add it or its ancestor to itself
        move_elements_safely attach: :extend_left, relative_to: extant, iterator: DomTraversor.new(teleft.text_element, extant, :enclosed_reversed)
        move_elements_safely attach: :extend_right, relative_to: extant, iterator: DomTraversor.new(extant, teright.text_element, :enclosed)
        @elmt_bounds.text_element_valid? extant
        return extant
      end
    end

    common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first
    # We can't attach the new node under an illegal ancestor, directly or indirectly
    while nknode_has_illegal_enclosure?(common_ancestor.children.first, tag) do
      common_ancestor = teleft.split_common teright
    end
    # Create a new tree, and move it to the appropriate place under common_ancestor
    newtree = (Nokogiri::HTML.fragment html_enclosure(tag: tag, rp_elmt_class: rp_elmt_class, value: value)).children[0]
    # We let #node_walk determine the insertion point: successor_node is the node that comes AFTER the new tree
    iterator = DomTraversor.new teleft.text_element, teright.text_element, :enclosed
    move_elements_safely attach: :extend_right, relative_to: newtree, iterator: iterator
    if iterator.successor_node # newtree goes where focus_root was
      elmt_bounds.attach_node_safely newtree, iterator.successor_node, :before # iterator.successor_node.previous = newtree
    else # The focus node was the last child, and now it's gone => make newtree be the last child
      elmt_bounds.attach_node_safely newtree, common_ancestor, :extend_right # common_ancestor.add_child newtree
    end
    # validate_embedding report_tree('After: ', newtree)
    nknode_clear_classification_context newtree, rp_elmt_class, parser_evaluator: @parser_evaluator
    @elmt_bounds.text_element_valid? newtree
    newtree
  end

end
