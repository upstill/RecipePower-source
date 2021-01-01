# ElmtBounds is an array corresponding to the text elements of a document
# Each element of the array is a pair: first, a text element as found in the document
# last, a global character offset
class ElmtBounds < Array
  attr_reader :nkdoc

  def initialize nkdoc
    @nkdoc = nkdoc
    @text_length = 0
  end

  def push text_elmt, global_char_offset
    super [ text_elmt, global_char_offset ]
  end

  def global_position_of_elmt elmt
    elmt_offset_at find_elmt_index(elmt)
  end

  def elmt_index_for_position global_position
    binsearch self, global_position, &:last
  end

  def nth_elmt ix
    self[ix]&.first
  end

  # Return the token_index-th text element
  def elmt_offset_at token_index
    # Defaults to the character position BEYOND the last text element
    (self[token_index]&.last if token_index) || (last.last + self.last.first.to_s.length)
  end

  def split_elmt_at ix, first_te, second_te
    self[ix][0] = first_te
    second_start = self[ix].last + first_te.to_s.length
    insert (ix += 1), [second_te, second_start]
  end

  # Replace the text element in the elmt_bounds array, BUT ONLY IF THE TEXT IS IDENTICAL
  def fix_nth_elmt ix, text_element
    begin
      self[ix][0] = text_element
    rescue Exception => e
      puts "ERROR maintaining @elmt_bounds array! Replacement does not match text of original"
    end
  end

  # Move a node into position in relation to element relative_to
  # CRITICALLY, we ensure that all text elements under the node are recorded in the elmt_bounds array
  def attach_node_safely node, relative_to, how
    parent = (how == :before || how == :after) ? relative_to.parent : relative_to
    if node.text?
      child_ix = find_elmt_index node
      prior_count = parent.children.count
    else
      elmt_bounds_index = nil
      node.traverse { |node| elmt_bounds_index ||= (find_elmt_index(node) if node.text?) }
    end

    # Now make the move
    as_attached =
        case how
        when :extend_right
          relative_to.add_child node
          relative_to.children.last
        when :extend_left
          if extant = relative_to.children.first
            extant.previous = node
          else
            # Degenerate case of an empty parent
            relative_to.add_child node
          end
          relative_to.children.first
        when :before
          relative_to.previous = node
          relative_to.previous
        when :after
          relative_to.next = node
          relative_to.next
        end

    # Finally, repair the element pointers as needed
    if node.text?
      if parent.children.count == prior_count # indicator that Nokogiri has merged adjacent text elements
        if how == :extend_left
          # Under the assumption that the inserted text-element has and will continue to precede
          # the first child, its index must be retained
          delete_at child_ix+1
        else
          # They should be adjacent elements in the elmts array
          delete_at child_ix
          child_ix = child_ix - 1
        end
      end
      self[child_ix][0] = as_attached
    else
      # Ensure that the node's text elements are maintained correctly in elmt_bounds
      node.traverse do |descendant|
        if descendant.text?
          fix_nth_elmt elmt_bounds_index, descendant
          elmt_bounds_index += 1
        end
      end if elmt_bounds_index
    end
  end

  # Provide the character range for a pair of text elements
  def range_encompassing first_text_element, last_text_element
    first_pos = last_pos = last_limit = nil
    each_with_index do |pair, index|
      if !first_pos && pair.first == first_text_element
        first_pos = pair.last
      end
      if !last_pos && pair.first == last_text_element
        last_pos = pair.last
        last_limit = elmt_offset_at(index+1)
        break
      end
    end
    [first_pos, last_limit]
  end

  private

  # Where in the array is the elmt kept?
  def find_elmt_index elmt
    find_index { |rcd| rcd.first.object_id.equal? elmt.object_id } if elmt
  end

end