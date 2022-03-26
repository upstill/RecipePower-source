# Library of methods on Nokogiri documents/nodes

# Ensure that nowhere in the node and its ancestry is there a grammar item that can't contain rp_elmt_class
# NB: since classes are strictly hierarchical, any ancestor bearing rp_elmt_class will be stripped of it.
def nknode_clear_classification_context node, rp_elmt_class, parser_evaluator: nil
  return unless rp_elmt_class

  node.ancestors.each do |ancestor|
    return if ancestor.fragment?
    if parser_evaluator && (classes = nknode_rp_classes ancestor).present?
      legit_classes = classes.find_all { |parent_class| parser_evaluator.can_include?(parent_class, rp_elmt_class) }
      nknode_rp_classes ancestor, legit_classes if legit_classes != classes
    end
  end
end

# Clean up the HTML of a node
def nknode_sanitize(node)
  # Turn <p> tags embedded in list tags (illegal) into <li> tags
  # Rename any paragraph tags under <ul> or <li> tags (without an intervening <li>) as <li>
  (node.css('ul p,ol p') - node.css('ul li p,ol li p')).each { |p| p.name = 'li' }
  node.css('script').remove
  node.css('span.loading').remove
  node
end

# Extract the CSS classes for a Nokogiri node, applying a regexp and converting all to symbols
def nknode_classes node, regexp=nil
  return [] unless classes = node['class']&.split
  classes.keep_if { |klass| klass.match(regexp) } if regexp
  classes.map &:to_sym
end

def nknode_rp_classes node, to_assign = nil
  if to_assign
    classes = nknode_classes(node).map(&:to_s).delete_if { |klass| klass.match /^rp_/ }
    classes += ['rp_elmt'] + to_assign.map(&:to_s) if to_assign.present?
    node['class'] = classes.join ' '
  else
    nknode_classes(node, /^rp_/).without :rp_elmt
  end
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

# Return all the predecessors of the node AS A NODESET
def nknode_siblings_before node
  node.parent.children[0...(node.parent.children.find_index { |child| child == node })]
end

# Return all the successors of the node AS A NODESET
def nknode_siblings_after node
  node.parent.children[(node.parent.children.find_index { |child| child == node }+1)..-1]
end

# Return all the siblings BEFORE this node AS AN ARRAY
def prev_siblings nokonode
  found = false
  nokonode.parent.children.collect { |child| child unless (found ||= child == nokonode) }.compact
end

# Return all the siblings AFTER this node
def next_siblings nokonode
  found = false
  nokonode.parent.children.collect { |child| found ? child : (found ||= child == nokonode; nil) }.compact
end

def nknode_text_before text_elmt, within: text_elmt.parent, starting_after: nil
  before = ''
  collecting = starting_after.nil?
  within.traverse do |node|
    return before if node.object_id == text_elmt.object_id
    before << node.text if node.text? && collecting
    collecting ||= (node.object_id == starting_after.object_id)
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

# Should a node be precluded from being enclosed in a tag b/c it has an incompatible ancestor?
def nknode_has_illegal_enclosure? node, tagname
  return false if tagname.blank?
  case tagname
  when 'li'
    node.ancestors.each do |anc|
      return false if ['ul', 'ol'].include?(anc.name)
    end
  end
  invalid_enclosures =
      case tagname.to_sym
      when :li, :div, :ul
        %w{ p }
      else
        []
      end
  invalid_enclosures.any? { |ivt| nknode_descends_from? node, tag: ivt }
end

# Does this text element have an ancestor of the given tag, with a class that includes the token?
def nknode_descends_from? node, tag: nil, token: nil
  token = token&.to_s
  node.ancestors.find do |ancestor|
    (tag.blank? || ancestor.name == tag) &&
        (token.blank? || nknode_has_class?(ancestor, token))
  end
end

def nknode_elevate_while node
  while yield(parent = node.parent) do
    parent.replace parent.children
  end
end

# What :rp_* classes have been applied to the tree containing this node?
def nknode_enclosing_classes node
  node.ancestors.collect { |ancestor|
    next unless (classes = ancestor['class']&.split)&.include? 'rp_elmt'
    classes.grep /^rp_/
  }.flatten.compact.map(&:to_sym).uniq
end

# Split the common ancestor of the two nodes in two, moving each node between them up to the parent's parent
def nknode_split_ancestor_of first, last
  #meta_ancestry = first.ancestors & last.ancestors
  #first = (first.ancestors - meta_ancestry).first || first
  #last = (last.ancestors - meta_ancestry).first || last
  #common_ancestor = meta_ancestry.first # Common ancestor
  overlap_index = -1 - (first.ancestors & last.ancestors).length
  first_sib = first.ancestors[overlap_index] || first
  last_sib = last.ancestors[overlap_index] || first
  common_ancestor = first_sib.parent
  family = common_ancestor.children
  first_ix, last_ix = family.index(first_sib), family.index(last_sib)
  to_move = family[first_ix..last_ix]
  gp = common_ancestor.parent
  if first_sib.previous.nil?
    # The first element in the parent: simply move the children before the parent's leftmost sibling
    to_move.remove
    common_ancestor.previous = to_move
  elsif last_sib.next.nil?
    # The last element in the parent: simply make it the parent's rightmost sibling
    to_move.remove
    common_ancestor.next = to_move
    newte = common_ancestor.next
  else
    # Worst case scenario: there is material before and after the node range
    # Split the parent at the te's index
    after = family[(last_ix+1)..-1]
    common_ancestor.next = common_ancestor.document.create_element(common_ancestor.name)
    after.remove
    common_ancestor.next.children = after
    common_ancestor.next = to_move
  end
  # Now we have to repair any damage to the @elmt_bounds array of text elements
  return gp
  if newte.object_id != text_element.object_id
    # Since the associated text_element has changed, we need to fix @elmt_bounds
    @text_element = newte
    @elmt_bounds.update_for gp, newte, @elmt_bounds_index
    if newte.object_id != text_element.object_id
      x=2
    end
  end
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
