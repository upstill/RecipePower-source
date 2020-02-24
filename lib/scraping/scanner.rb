require 'string_utils.rb'
require 'binsearch.rb'
require 'scraping/text_elmt_data.rb'
require 'scraping/noko_tokens.rb'

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
  nokonode.parent.children.collect { |child| found ? child : (found ||= child == nokonode ; nil) }.compact
end

# Move all the text enclosed in the tree between anchor_elmt and focus_elmt, inclusive, into an enclosure that's a child of
# the common ancestor of the two.
 def assemble_tree_from_nodes anchor_elmt, focus_elmt, options={}
  html = html_enclosure(options) # insert=true
  common_ancestor = (anchor_elmt.ancestors & focus_elmt.ancestors).first

  # We'll attach the new tree as the predecessor node of the anchor element's highest ancestor
  left_ancestor = (anchor_elmt if anchor_elmt.parent == common_ancestor) ||
      anchor_elmt.ancestors.find { |elmt| elmt.parent == common_ancestor }
  newtree =
      if options[:insert] != false
        left_ancestor.previous = html
        left_ancestor.previous
      else
        Nokogiri::HTML.fragment(html).children[0]
      end
  left_collector = left_ancestor.next
  
  highest_whole_left = anchor_elmt
  while (highest_whole_left.parent != common_ancestor) && !highest_whole_left.previous_sibling do
    highest_whole_left = highest_whole_left.parent
  end
  # Starting with the highest whole node, add nodes that are included in the selection to the new elmt
  right_collector = highest_whole_left.next
  newtree.add_child highest_whole_left
  while (right_collector.parent != common_ancestor)
    parent = right_collector.parent
    while (right_sib = right_collector.next) do
      right_collector = right_sib.next
      newtree.add_child right_sib
    end
    right_collector = parent
  end
  ## Now do the same with the right side, adding preceding elements
  # Find the highest node that can be moved whole
  highest_whole_right = focus_elmt
  while (highest_whole_right.parent != common_ancestor) && !highest_whole_right.next_sibling do
    highest_whole_right = highest_whole_right.parent
  end
  # Build a stack from the right node's ancestor below the common ancestor down to the highest whole right node
  stack = [ highest_whole_right ]
  while stack.last.parent != common_ancestor
    stack.push stack.last.parent
  end
  # Go down the tree, collecting all the siblings before and including each ancestor
  while ancestor = stack.pop
    while left_collector != ancestor do
      next_sib = left_collector.next_sibling
      newtree.add_child left_collector
      left_collector = next_sib
    end
    left_collector = ancestor.children[0] unless stack.empty?
  end
  newtree.add_child highest_whole_right
  newtree
end

def html_enclosure options={}
  tag = options[:tag] || 'div'
  classes = "rp_elmt #{options[:classes]}".strip
  "<#{tag} class='#{classes}'></#{tag}>" # For constructing the new node
end

# A Scanner object provides a stream of input strings, tokens, previously-parsed entities, and delimiters
# This is an "abstract" class for defining what methods the Scanner provides
class Scanner < Object
  attr_reader :pos

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek ntokens = 1

  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first

  end

  # Move past the current string, adjusting 'next' and returning a stream for the remainder
  def rest nchars = 1

  end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  # Provide a string representing the content of the stream from its current position, terminating at the bound
  def to_s limit=@bound
    peek (limit - @pos)
  end

end

# Scan an input (space-separated) stream. When the stream is exhausted, #more? returns false
class StrScanner < Scanner
  attr_reader :strings, :pos, :bound # :length

  def initialize strings, pos = 0, bound = nil
    # We include punctuation and delimiters as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @strings = strings
    @pos = pos
    # @length = @strings.count
    @bound = bound || @strings.count
  end

  def self.from_string string, pos = 0
    self.new tokenize(string), pos
  end

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars = 1
    if @pos < @bound # @length
      (nchars == 1) ? @strings[@pos] : @strings[@pos...(@pos + nchars)].join(' ')
    end
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first nchars = 1
    if @pos < @bound # @length
      f = @strings[@pos...(@pos + nchars)]&.join(' ')
      @pos += nchars
      @pos = @bound if @pos > @bound # @length if @pos > @length
      f
    end
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars = 1
    newpos = @pos + nchars
    # StrScanner.new(@strings, (newpos > @length ? @length : newpos))
    StrScanner.new(@strings, (newpos > @bound ? @bound : newpos), @bound)
  end

  def more?
    @pos < @bound # @length
  end

end

class NokoScanner
  attr_reader :nkdoc, :pos, :bound, :tokens
  delegate :pp, to: :nkdoc
  delegate :elmt_bounds, :token_starts, :token_offset_at, :enclose_by_token_indices, :text_elmt_data, to: :tokens

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc_or_nktokens_or_html, pos = 0, bound=nil # length=nil
    # Take the parameters as instance variables, creating @tokens if nec.
    case nkdoc_or_nktokens_or_html
    when NokoTokens
      @tokens = nkdoc_or_nktokens_or_html
      @nkdoc = nkdoc_or_nktokens_or_html.nkdoc
    when String
      @nkdoc = Nokogiri::HTML.fragment nkdoc_or_nktokens_or_html
      @tokens = NokoTokens.new @nkdoc
    else # It's a Nokogiri doc!
      @nkdoc = nkdoc_or_nktokens_or_html
      @tokens = NokoTokens.new nkdoc_or_nktokens_or_html
    end
    @bound = bound || @tokens.length
    @pos = pos
  end

  def self.from_string html
    self.new Nokogiri::HTML.fragment(html)
  end

  # Return the stream of tokens as an array of strings
  def strings
    tokens.collect { |token| token.is_a?(NokoScanner) ? token.strings : token }.flatten
  end

  def peek ntokens = 1
    if @pos < @bound # @length
      if ntokens == 1
        tokens[@pos]
      elsif tokens[@pos...(@pos + ntokens)].all? { |token| token.is_a? String } # ONLY IF NO TOKENS
        tokens[@pos...(@pos + ntokens)].join(' ')
      end
    end
  end

  # Output version of #peek: the original text, rather than a joined set of tokens
  def to_s limit=@bound
    # peek limit-@pos      Gives tokens joined by a space: not quite the same thing
    tokens.text_from @pos, limit
  end

  # Report the token no matter if the position is beyond the bound
  def token_at
    tokens[@pos]
  end

  # Is the scanner at a newline: either the first token, or a token preceded by "\n"
  def atline?
    (@pos >= 0) && (tokens[@pos-1] == "\n")
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first ntokens = 1
    if str = peek(ntokens)
      @pos += ntokens
      @pos = @bound if @pos > @bound # @length if @pos > @length
    end
    str
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest ntokens = 1
    newpos = @pos + ntokens
    NokoScanner.new tokens, (newpos > @bound ? @bound : newpos), @bound # (newpos > @length ? @length : newpos), @length
  end

  def chunk data
    if (data || (ptr == (head + 1)))
      head = ptr
    end
  end

  def more?
    @pos < @bound # @length
  end

  # Create a scanner that starts where the given scanner starts
  def goto s2
    NokoScanner.new tokens, s2.pos, @bound
  end

  # Create a scanner that ends at the given scanner
  def except s2
    NokoScanner.new tokens, @pos, s2.pos # (newpos > @length ? @length : newpos), @length
  end

  # Make the end of the stream coincident with another stream
  def encompass s2
    # @length = s2.length
    @bound = s2.bound if s2.bound > @bound
  end

  # Return a scanner, derived from the instance's Nokogiri DOM, restricted to the given CSS match
  def within_css_match str
    if range = @tokens.dom_range(str)
      return NokoScanner.new @tokens, range.begin, range.end
    end
  end

  # Return an ARRAY of scanners, as above
  def within_css_matches str
    @tokens.dom_ranges(str).map { |range|
      next if range.begin < @pos
      NokoScanner.new @tokens, range.begin, range.end
    }.compact
  end

  # Provide xpath and offset for locating the current position in the document
  def xpath terminating=false
    @nkdoc.children.first
    ted = TextElmtData.new @tokens, @tokens.token_offset_at(@pos)*(terminating ? -1 : 1)
    ted.xpath
  end

  def enclose_to limit, options={}
    return unless limit > pos
    @tokens.enclose_by_token_indices @pos, limit, options
  end

end
