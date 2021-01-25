# Library of methods on Nokogiri documents/nodes

# Clean up the HTML of a node
def nknode_sanitize(node)
  # Turn <p> tags embedded in list tags (illegal) into <li> tags
  node.css('ul p,ol p').each { |found| found.name = 'li' }
  node
end

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

def nknode_apply node, rp_elmt_class:, value:
  nknode_add_classes node, "rp_elmt #{rp_elmt_class}"
  node['value'] = value if value
end

  # Test a text element or a whole tree to ensure that it can be properly accessed
def nknode_valid? node
  node.traverse do |node_or_text_element|
    if node_or_text_element.text?
      text_elmt = node_or_text_element
      begin
        throw "Node can't be found among its parent's children" if text_elmt.parent.children.index(text_elmt).nil?
        progenitor = text_elmt.ancestors.first
        throw "Node's ancestors can't be found among progenitor's children" if progenitor && (progenitor.children & text_elmt.ancestors).nil?
      rescue Exception => exc
        return false
      end
    end
    true
  end
end

def nknode_first_text_element node
  node.text? ? node : node.traverse { |node| return node if node.text? }
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

def nknode_text_before text_elmt, within: text_elmt.parent
  before = ''
  within.traverse do |node|
    return before if node.object_id == text_elmt.object_id
    before << node.text if node.text?
  end
  before
end

def nknode_text_after text_elmt, within: text_elmt.parent
  after = nil
  within.traverse do |node|
    after << node.text if node.text? && after
    after = '' if node.object_id == text_elmt.object_id
  end
  after || ''
end

def nknode_predecessor_text_elmt tree, text_elmt
  prev = nil
  tree.traverse do |node|
    return prev if node == text_elmt # NB: will return nil if no predecessor
    if node.text?
      prev = node
    end
  end
end

def nknode_successor_text_elmt tree, text_elmt
  passed = false
  tree.traverse do |node|
    return node if passed && node.text?
    passed = true if node == text_elmt
  end
end

# Find the first text element under the node with non-blank text
def first_text_element node, nonblank = true
  node.traverse do |child|
    return child if child.text? && (nonblank ? child.text.match(/\S/) : child.text.present?)
  end
end

# Find the last text element under the node with non-blank text
def last_text_element node, nonblank = true
  last = nil
  node.traverse do |child|
    last = child if child.text? && (nonblank ? child.text.match(/\S/) : child.text.present?)
  end
  last
end

# Find a parent of the text_element which won't be split in a tree walk.
# if how is :blank_left, the ancestor qualifies if it only has blank text before the text_element
# if how is :blank_right, the ancestor qualifies if it only has blank text after the text_element
# limit: an ancestor of text_element that the search should stop before
def undivided_ancestor text_element, how, limit
  anc = text_element
  node = text_element.parent
  while !node.fragment? &&
      node != limit &&
      text_element == (how == :blank_left ? first_text_element(node) : last_text_element(node)) &&
      (!block_given? || yield(node)) do
    anc = node
    node = node.parent
  end
  anc
end
