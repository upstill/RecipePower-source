## Library of methods for extending functionality of Nokogiri
class DomTraversor
  attr_reader :successor_node

  def initialize anchor_node, focus_node, how=:enclosed
    @anchor_node, @focus_node, @how = anchor_node, focus_node, how
    nknode_valid? @anchor_node
    nknode_valid? @focus_node
    @anchor_ancestry = @anchor_node.ancestors
    @focus_ancestry = @focus_node.ancestors
    while @anchor_ancestry.last && @focus_ancestry.last == @anchor_ancestry.last
      common_ancestor = @focus_ancestry.pop
      @anchor_ancestry.pop
    end
    @anchor_root = @anchor_node
    while @anchor_root.parent != common_ancestor
      @anchor_root = @anchor_root.parent
    end

    @focus_root = @focus_node
    while @focus_root.parent != common_ancestor
      @focus_root = @focus_root.parent
    end
  end

  # iterator covering a tree walk from anchor_node to focus_node, inclusive. Call the block at
  # each node.
  # When collecting a set of nodes from the inside of the tree encompassing the two nodes,
  # establish @successor_node as a valid place to insert a tree containing those nodes that
  # maintains the same tree order.
  def walk
    nodes =
    case @how
    when :enclosed
      across
    when :enclosed_reversed
      across.reverse
    when :left
      left_of_path
    when :right
      right_of_path
    end
    # Now pass the visited nodes back to the caller
    nodes = nodes.uniq
    nodes.each { |node| yield node } if block_given?
    nodes
  end

  # Do a depth-first enumeration of nodes in the tree BETWEEN the anchor and the focus,
  # walking up to their common ancestor, then across to the node containing (however indirectly)
  # @focus_node
  def across
    # We're going to collect a list of nodes to be moved under the new tree, in order
    anchor_ancestry = @anchor_node.ancestors
    focus_ancestry = @focus_node.ancestors
    common_ancestry = anchor_ancestry & focus_ancestry
    common_ancestor = common_ancestry.first

    path_to_anchor_root = [@anchor_node] + (anchor_ancestry - common_ancestry).to_a
    # The anchor_root is the first element on the anchor path, a child of common_ancestor
    anchor_root = path_to_anchor_root.pop
    # The degenerate case: the anchor (focus) root is the same as @anchor_node (@focus_node)

    # path_to_focus_elmt runs from below focus root to @focus_node
    path_to_focus_elmt = (focus_ancestry - common_ancestry).to_a.reverse << @focus_node
    focus_root = path_to_focus_elmt.shift

    if anchor_root == focus_root # Simple case: anchor path and focus path land on the same text element
      @successor_node = anchor_root.next
      result = [anchor_root]
    else

      # We are going to develop an array of nodes to assign to the children of newtree.
      result = []

      # Highest_whole_{left|right} are the root of subtrees whose text elements lie entirely within
      # the range from anchor to focus, if any (otherwise, they are the anchor and/or focus elements themselves)
      # The first element of the new tree is the highest ancestor of @anchor_node that can be included in its entirety,
      # i.e., all of its children are in range. There might be NO such element: @anchor_node may have previous siblings

      while path_to_anchor_root.first && !path_to_anchor_root.first.previous && !path_to_anchor_root.first.next do
        path_to_anchor_root.shift
      end
      result.push path_to_anchor_root.first || anchor_root
      path_to_anchor_root.each do |caret|
        while caret = caret.next_sibling do
          result.push caret
        end
      end

      # Add the nodes between the two roots, if any
      if (caret = anchor_root) != focus_root
        while (caret = caret.next) != focus_root
          result.push caret
        end
      end

      # Find the the last node on path_to_focus_element that can be moved in its entirety
      # i.e., the one with no children to the left of the one on the path
      while path_to_focus_elmt.last && !path_to_focus_elmt.last.next && !path_to_focus_elmt.last.previous do
        path_to_focus_elmt.pop
      end
      # ...but the search may have consumed the whole path without finding one
      if path_to_focus_elmt.present?
        # Process each node in the path down from (but not including) last_element
        # by collecting leftward siblings
        path_to_focus_elmt.each do |right_sibling|
          right_sibling.parent.children.each { |caret|
            break if caret == right_sibling
            result.push caret
          }
        end
      end
      result.push path_to_focus_elmt.last || focus_root
      @successor_node = result.include?(focus_root) ? focus_root.next : focus_root
    end
    result
  end

  # Collect nodes OUTSIDE the path, to the LEFT
# collect nodes to the left of the path from anchor_node to focus_node exclusive.
# @anchor_node must be a descendant of @focus_node
  def left_of_path
    result = []
    mark = @anchor_node
    while mark != @focus_node
      previous = mark
      mark = mark.parent
      while previous = previous.previous
        result.push previous
      end
    end
    result.reverse
  end

  # Collect nodes OUTSIDE the path, to the RIGHT
  def right_of_path
    result = []
    mark = @focus_node
    while mark != @anchor_node
      nxt = mark
      mark = mark.parent
      while nxt = nxt.next
        result.push nxt
      end
    end
    result
  end
end

####### Utility functions #####################

# Break up a node's children as necessary to avoid subtrees that fail a test (implemented as a block)
def processed_children node, &block
  # Recursively examine the node, returning an array of valid descendants or, if they are all valid, the node itself
  def do_children node, &block
    return [ node ] if node.text?
    all_good = true
    collected = node.children.collect do |child|
      subcollection = do_children child, &block
      all_good &&= (subcollection == [ child ])
      subcollection
    end
    # Keep the node whole if all its children are good and the block approves
    return [ node ] if all_good && block_given? && block.call(node)
    collected.flatten
  end
  # For each potential new child, look into expanding it and/or approving it by calling the block
  do_children node, &block
end
