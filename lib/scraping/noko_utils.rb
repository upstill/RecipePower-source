# Library of methods on Nokogiri documents/nodes

# Extract the CSS classes for a Nokogiri node, applying a regexp and converting all to symbols
def nknode_classes node, regexp=nil
  return [] unless classes = node['class']&.split
  classes.keep_if { |klass| klass.match(regexp) } if regexp
  classes.map &:to_sym
end

def nknode_has_class? node, css_class
  node['class']&.split&.include?(css_class.to_s) if node
end

def nknode_add_classes node, css_classes
  absent = css_classes.split.collect { |css_class|
    css_class unless nknode_has_class? node, css_class
  }.compact.join(' ')
  node['class'] = "#{node['class']} #{absent}"
end

def nknode_apply node, classes:, value:
  nknode_add_classes node, "rp_elmt #{classes}"
  node['value'] = value if value
end

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