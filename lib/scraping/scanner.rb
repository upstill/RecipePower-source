require 'string_utils.rb'
require 'binsearch.rb'

# Is the node ready to delete?
def node_empty? nokonode
  return nokonode.text.match /^\n*$/ if nokonode.text? # A text node is empty if all it contains are newlines (if any)
  nokonode.children.blank? || nokonode.children.all? { |child| node_empty? child }
end

# A Scanner object provides a stream of input strings, tokens, previously-parsed entities, and delimiters
# This is an "abstract" class for defining what methods the Scanner provides
class Scanner < Object
  attr_reader :pos

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars=1

  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first

  end

  # Move past the current string, adjusting 'next' and returning a stream for the remainder
  def rest nchars=1

  end

  def chunk data
    if(data || (ptr == (head+1)))
      head = ptr
    end
  end

end

# Scan an input (space-separated) stream. When the stream is exhausted, #more? returns false
class StrScanner < Scanner
  attr_reader :strings, :pos, :length

  def initialize strings, pos=0
    # We include punctuation and delimiters as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @strings = strings
    @pos = pos
    @length = @strings.count
  end

  def self.from_string string, pos=0
    self.new tokenize(string), pos
  end

  # peek: return the string (one or more words, space-separated) in the current "read position" without advancing
  def peek nchars=1
    if @pos < @length
      (nchars == 1) ? @strings[@pos] : @strings[@pos...(@pos+nchars)].join(' ')
    end
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first nchars = 1
    if @pos < @length
      f = @strings[@pos...(@pos + nchars)]&.join(' ')
      @pos += nchars
      @pos = @length if @pos > @length
      f
    end
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars=1
    newpos = @pos + nchars
    StrScanner.new(@strings, (newpos > @length ? @length : newpos))
  end

  def more?
    @pos < @length
  end

end

class NokoScanner
  attr_reader :pos, :nkdoc, :tokens, :elmt_bounds, :token_starts

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc, pos=0, tokens=nil
    def to_tokens newtext = nil
      # Prepend the string to the priorly held text, if any
      newtext = @held_text + newtext if newtext && @held_text && (@held_text.length > 0)
      @held_text = tokenize((newtext || @held_text), newtext == nil) { |token, offset|
        @tokens.push token
        @token_starts.push @processed_text_len + offset
      }
      @processed_text_len += newtext.length if newtext
      @processed_text_len -= @held_text.length
    end

    def do_child child
      case
      when child.text?
        # Save this element and its starting point
        @elmt_bounds << [child, (@processed_text_len+@held_text.length)]
        to_tokens child.text
      when child.attributes['class']&.value&.match(/\brp_elmt\b/)
        to_tokens
        @tokens << NokoScanner.new(child)
      when child.element?
        to_tokens "\n" if child.name.match(/^(p|br|li)$/)
        child.children.each { |j| do_child j }
      end
    end

    # Take the parameters as instance variables, creating @tokens if nec.
    @nkdoc = nkdoc
    @pos = pos

    if !(@tokens = tokens)
      @tokens = []
      @elmt_bounds = []
      @token_starts = []
      @processed_text_len = 0
      @held_text = ''
      @nkdoc.children.each { |j| do_child j }
      to_tokens # Finally flush the last text
    end
    @length = @tokens.count
  end

  def self.from_string html
    self.new Nokogiri::HTML.fragment(html)
  end

  # Return the stream of tokens as an array of strings
  def strings
    @tokens.collect { |token| token.is_a?(NokoScanner) ? token.strings : token }.flatten
  end

  def peek nchars=1
    if @pos < @length
      if nchars == 1
        @tokens[@pos]
      elsif @tokens[@pos...(@pos+nchars)].all? { |token| token.is_a? String } # ONLY IF NO TOKENS
        @tokens[@pos...(@pos+nchars)].join(' ')
      end
    end
  end

  # first: return the string in the current "read position" after advancing to the 'next' position
  def first nchars = 1
    if str = peek(nchars)
      @pos += nchars
      @pos = @length if @pos > @length
    end
    str
  end

  # Move past the current string, adjusting '@pos' and returning a stream for the remainder
  def rest nchars=1
    newpos = @pos + nchars
    NokoScanner.new @nkdoc, (newpos > @length ? @length : newpos), @tokens
  end

  def chunk data
    if(data || (ptr == (head+1)))
      head = ptr
    end
  end

  def more?
    @pos < @length
  end

  # Modify the Nokogiri document to enclose the strings designated by pos_begin and pos_end in a <div> of the given classes
  def enclose pos_begin, pos_end, classes=''
    def replace_elmt elmt, replacement
      # We enclose all the material in a <span> node, then collapse it
      replacement = "<span>#{replacement}</span>"
      puts "Replacing '#{elmt.text}' with '#{replacement}'."
      parent = elmt.parent
      nodeset = elmt.replace replacement
      newnode = parent.children.find { |child|
        child == nodeset[0]
      }
      newnode.replace newnode.children
    end
    # Provide a hash of data about the text node that has the token at 'pos_begin'
    teleft = text_elmt_data pos_begin
    newbounds = []
    if teleft.encompasses_offset pos_end
      # We're in luck! Both beginning and end are on the same text node
      # so we replace the text node with (possibly) two text nodes surrounding the new element
      newchildren = replace_elmt teleft.text_element,
                            "#{teleft.prior_text}<div class='np_elmt #{classes}'>#{teleft.delimited_text pos_end}</div>#{teleft.subsq_text pos_end}"

      # Now we need to adjust the elmt bounds for the 
      new_elmt = newchildren.find { |child| child.element? }
      where = teleft.global_start_offset
      if newchildren.first.text?
        newbounds << [newchildren.first, where]
        where += newchildren.first.text.length
      end
      newbounds << [new_elmt.children.first, where]
      where += new_elmt.children.first.text.length
      newbounds << [newchildren.last, where] if newchildren.last.text?
    else
      teright = text_elmt_data -(pos_end)
      # Find the common ancestor of the two text nodes
      common_ancestor = (teleft.ancestors & teright.ancestors).first
      # Capture the elements between the two text elements
      # Capture the text from the first element
      start_html = teleft.subsq_text
      # For all ancestors of the start node, up to but not including the common ancestor, add their rightmost
      # elements to the enclosure

      left_elmt = teleft.text_element
      while (left_elmt.parent != common_ancestor)
        while sib = left_elmt.next_sibling
          start_html << sib.to_s
          sib.remove
        end
        left_elmt = left_elmt.parent
      end

      end_html = teright.prior_text
      right_elmt = teright.text_element
      while (right_elmt != common_ancestor)
        # Collect elements to the left
        while (sib = right_elmt.previous_sibling) && (sib != left_elmt)
          end_html = sib.to_s + end_html
          sib.remove
        end
        right_elmt = right_elmt.parent
      end

      # right_elmt has ascended to the common ancestor.
      # All relevant nodes have been converted to html and deleted
      # All html for the replacement is in start_html + end_html
      # left_elmt is the first relevant child of the common ancestor
      left_elmt.next = "<div class='np_elmt #{classes}'> #{start_html} #{end_html} </div>"
      new_elmt = left_elmt.next_sibling

      # Now the appropriate elements have been built, we can reset the text of the initial
      # text elements, and Nokogiri can maintain the tree appropriately
      teleft.content = teleft.prior_text
      left_elmt.remove if node_empty? left_elmt
      teright.content = teright.subsq_text
      new_elmt.next_sibling.remove if node_empty? new_elmt.next_sibling
    end
    # @tokens[pos_begin...pos_end] = NokoScanner.new new_elmt
    teleft.replace_bound newbounds, 0 # pos_end-pos_begin-1
  end

  def text_elmt_data char_offset
    TextElmtData.new self, char_offset
  end

end

class TextElmtData < Object
  delegate :parent, :text, :'content=', :delete, :ancestors, to: :text_element
  delegate :elmt_bounds, to: :noko_scanner
  attr_accessor :elmt_bounds_index, :text_element, :parent
  attr_reader :noko_scanner, :local_char_offset, :global_start_offset

  def initialize nks, global_char_offset # character offset (global)
    global_char_offset = (terminating = global_char_offset < 0) ? (-global_char_offset) : global_char_offset
    @noko_scanner = nks
    @elmt_bounds_index = binsearch elmt_bounds, global_char_offset, &:last
    # Boundary condition: if the given offset is at a node boundary AND the given offset was negative, we are referring to the prior node
    @elmt_bounds_index -= 1 if terminating && (@elmt_bounds_index > 0) && (elmt_bounds[@elmt_bounds_index].last == global_char_offset)
    @text_element, @global_start_offset = elmt_bounds[@elmt_bounds_index]
    @local_char_offset = global_char_offset - @global_start_offset
    @parent = @text_element.parent
  end

  # Does the text element include the text at the end offset
  def encompasses_offset end_offset
    text_element.text[end_offset - @global_start_offset - 1] != nil
  end

  # Return the text of the text element prior to the selection point
  def prior_text
    text[0...@local_char_offset]
  end

  # Return the text from the mark to the end of the text element
  def subsq_text mark=@local_char_offset
    text[mark..-1]
  end

  def delimited_text mark=nil
    text[mark ? @local_char_offset...mark : @local_char_offset..-1]
  end

  def replace_bound newbounds, text_shrinkage=0
    elmt_bounds[@elmt_bounds_index..-1].each { |pair| pair[1] -= text_shrinkage } if text_shrinkage != 0
    if newbounds.empty?
      elmt_bounds.delete_at @elmt_bounds_index
    else
      elmt_bounds[@elmt_bounds_index..@elmt_bounds_index] = newbounds
    end
  end

  def remove
    child = text_element
    while (parent = child.parent)
      child.remove
      break if parent.children.count != 0
      child = parent
    end
  end

=begin
  # Set the text for the element to 'str'. Delete the element if the text is empty
  def text= str
    if str.present?
      @text_element.text = str
    else
      @text_element.delete
      @text_element = nil
    end
  end
=end
end
