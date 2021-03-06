# ElmtBounds is an array corresponding to the text elements of a document
# Each element of the array is a pair: first, a text element as found in the document
# last, a global character offset
class ElmtBounds < Array
  attr_reader :nkdoc

  def initialize nkdoc
    @nkdoc = nkdoc
    @text_length = 0
    nkdoc.traverse do |node|
      if node.text?
        push [ node, @text_length ]
        @text_length += node.text.length
      end
    end
  end

=begin
  def push text_elmt, global_char_offset
    super [ text_elmt, global_char_offset ]
  end
=end

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
  def replace_nth_element ix, text_elmt
    old_te = nth_elmt ix
    if old_te.text != text_elmt.text
      error = "Bogus attempt to set ##{ix}-th element '#{}' to '#{text_elmt.text}'"
      throw error
    end
    self[ix][0] = text_elmt
  end

  # Define the nodeset as the children of relative_to
  def attach_nodes_safely nodeset, relative_to
    # Find the first text element to use as an anchor
    nodeset.each do |node| # Find a node with a text element to use as anchor
      if (anchor_te = nknode_first_text_element(node)) && (anchor_ix = find_elmt_index anchor_te)
        relative_to.children = nodeset
        # Ensure that the node's text elements are maintained correctly in elmt_bounds
        # The first text element in the node set becomes the first text element under relative_to
        update_for relative_to, nknode_first_text_element(relative_to), anchor_ix
        return relative_to
      end
    end
  end

  # Move a node into position in relation to element relative_to
  # CRITICALLY, we ensure that all text elements under the node are recorded in the elmt_bounds array
  def attach_node_safely node, relative_to, how=:extend_right
    parent = (how == :before || how == :after) ? relative_to.parent : relative_to
    if node.text?
      anchor_te = node
      prior_count = parent.children.count
    else
      # Use the first text element in the tree as an anchor, if any
      anchor_te = nknode_first_text_element(node)
    end
    # We will know the location (anchor_ix) in our array of at least one text element (anchor_te)
    # This will give us a constant location to ensure that all related text elements
    # (ie., those under the node or its parent) can be renewed
    anchor_ix = find_elmt_index anchor_te

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
          delete_at anchor_ix+1
        else
          # They should be adjacent elements in the elmts array
          delete_at anchor_ix
          anchor_ix = anchor_ix - 1
        end
      end
      # The node may have changed after being attached, but we WILL have an anchor_ix
      update_for parent, as_attached, anchor_ix
    else
      # Ensure that the node's text elements are maintained correctly in elmt_bounds
      update_for as_attached, nknode_first_text_element(as_attached), anchor_ix if anchor_ix # There mightn't be a text element 
    end
  end

  # Ensure that 1) the text element can be found in the array, and
  # 2) it is properly embedded in the tree
  def text_element_valid? node
    node.traverse do |self_or_descendant|
      if self_or_descendant.text?
        begin
          if find_elmt_index(self_or_descendant).nil?
            throw "Text element for '#{self_or_descendant.text}' can't be found in elmt_bounds."
          end
        rescue Exception => exc
          return false
        end
        return false unless nknode_valid?(self_or_descendant)
      end
    end
    return true
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


  def update_for parent, anchor_te, anchor_ix
    # How many text elements precede anchor_te under parent?
    def preceding_text_elmts te
      count = 0
      te.parent.traverse do |node|
        if node.text?
          if node.object_id == te.object_id
            return count
          else
            count += 1
          end
        end
      end
    end
    replace_nth_element anchor_ix, anchor_te
    # ix is the index in our array of the first text element under the parent
    ix = anchor_ix - preceding_text_elmts(anchor_te)
    parent.traverse do |node|
      if node.text?
        replace_nth_element ix, node
        ix += 1
      end
    end
  end

  # Where in the array is the elmt kept?
  def find_elmt_index elmt
    return nil unless elmt&.text?
    find_index { |rcd| rcd.first.object_id.equal? elmt.object_id }
  end

=begin
      text_elmts = []
      first_te_ix = nil
      parent.traverse do |node|
        if node.text?
          first_te_ix = child_ix - text_elmts.count if node == as_attached
          text_elmts.push node
        end
      end
      text_elmts.each do |te|
        if self[first_te_ix].first != te
          if self[first_te_ix].first.text != te.text
            throw "Attempt to replace @elmt_bounds[#{first_te_ix}] (#{self[first_te_ix].first.text}) with non-matching #{te.text}"
          end
          self[first_te_ix][0] = te
        end
        first_te_ix += 1
      end
      ted = TextElmtData.new(self, self[child_ix].last)
      ted.valid?
=end
end