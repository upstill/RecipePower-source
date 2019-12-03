require 'string_utils.rb'
require 'binsearch.rb'
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
  attr_reader :pos, :nkdoc, :tokens, :elmt_bounds

  # To initialize the scanner, we build:
  # - an array of tokens, each either a string or an rp_elmt node
  # - a second array of elmt_bounds, each a pair consisting of a text element and an offset in the tokens array
  def initialize nkdoc, pos=0, tokens=nil
    def tokenize_text_buffer newtext = ''
      # We accumulate a long string by concatenating text from Text elements,
      # and converting it to tokens when appropriate. NB We can't just tokenize text as we go,
      # because a single string might have content in different Text elements
      # for example, "a quite<span>long</span>string" has three text elements but only two tokens
      newtokens = @text.split("\n").collect { |line| ["\n"] + tokenize(line) }.flatten
      newtokens.shift unless @text.match /^\s*\n/
      @tokens += newtokens
      @text = newtext || ''
    end
    def do_child child
      case
      when child.text?
        newtext = child.text.gsub "\n", ' '
        tokenize_text_buffer if newtext.match /^\s/ # The saved text can be flushed
        # Save this element and its starting point
        @elmt_bounds << [ child, @tokens.count ]
        # Save whatever's after the last whitespace for the next text node
        if match = newtext.match(/(^.*\s)(.*$)/)
          @text << match[1]
          tokenize_text_buffer match[2]
        else
          # No whitespace at all => the entirety of the string should be buffered up
          @text << newtext
        end
      when child.attributes['class']&.value&.match(/\brp_elmt\b/)
        tokenize_text_buffer
        @tokens << NokoScanner.new(child)
      when child.element?
        @text << "\n" if child.name.match(/^(p|br|li)$/)
        child.children.each{ |j| do_child j }
      end
    end
    # Take the parameters as instance variables, creating @text and @tokens as nec.
    @nkdoc = nkdoc
    @pos = pos
    @tokens = tokens
    if !@tokens
      @tokens = []
      @elmt_bounds = []
      @text = ''
      @nkdoc.children.each { |j| do_child j }
      tokenize_text_buffer  # Finally flush the last text
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
    first_ix = binsearch @elmt_bounds, pos_begin, &:last
    # first_ix gives the @elmt_bounds index of the first token
    first_text_elmt, first_token = @elmt_bounds[first_ix]

    last_ix = binsearch @elmt_bounds, pos_end, &:last
    # last_ix gives the @elmt_bounds index of the last token
    last_text_elmt, last_token = @elmt_bounds[last_ix]

    if first_text_elmt == last_text_elmt
      endoff = @elmt_bounds[first_ix+1]&.last || @tokens.count
      puts "text node starts at #{first_token} and ends at #{endoff}"
      # We're in luck! We landed on the same text node
      before = @tokens[first_token...pos_begin].join ' '
      content = @tokens[pos_begin...pos_end].join ' '
      after = @tokens[pos_end...endoff].join ' '

      newchildren = replace_elmt first_text_elmt,
                            "#{before}<div class='np_elmt #{classes}'> #{content} </div>#{after}"

      # We've lost some number of tokens and added the one for the new NokoScanner
      shrinkage = @tokens.count
      @tokens[pos_begin...pos_end] = NokoScanner.new(newchildren.find { |child| child.element? })
      shrinkage -= @tokens.count
      # @elmt_bounds past the replacement point need to have their token indices adjusted accordingly
      newbounds = []
      if (tn = newchildren[0]).text?
        newbounds << [tn, first_token]
        update_from = first_ix+1
      else
        update_from = first_ix
      end
      if (tn = newchildren[-1]).text?
        newbounds << [tn, pos_end]
      end
      if newbounds.empty?
        @elmt_bounds.delete_at first_ix
      else
        @elmt_bounds[first_ix..first_ix] = newbounds
      end
      if shrinkage != 0
        @elmt_bounds[update_from..-1].each { |pair| pair[1] -= shrinkage }
      end
    end
  end

end

