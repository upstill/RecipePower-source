# Library of methods on Nokogiri documents/nodes

# Is the node ready to delete?
def node_empty? nokonode
  return nokonode.text.match /^\n*$/ if nokonode.text? # A text node is empty if all it contains are newlines (if any)
  nokonode.children.blank? || nokonode.children.all? { |child| node_empty? child }
end

# Return all the siblings BEFORE this node
def prev_siblings nokonode
  found = false
  nokonode.parent.children.collect { |child| child unless (found ||= child == nokonode) }.compact
end

# Return all the siblings AFTER this node
def next_siblings nokonode
  found = false
  nokonode.parent.children.collect { |child| found ? child : (found ||= child == nokonode; nil) }.compact
end

def first_text_element node, blanks_okay = false
  node.traverse do |child|
    return child if child.text? && (blanks_okay || child.text.present?)
  end
end

def last_text_element node, blanks_okay = false
  last = nil
  node.traverse do |child|
    last = child if child.text? && (blanks_okay || child.text.present?)
  end
  last
end

def predecessor_text tree, text_elmt
  prev = nil
  tree.traverse do |node|
    return prev if node == text_elmt # NB: will return nil if no predecessor
    if node.text?
      prev = node
    end
  end
end

def successor_text tree, text_elmt
  passed = false
  tree.traverse do |node|
    return node if passed && node.text?
    passed = true if node == text_elmt
  end
end

class NokoUtils
end