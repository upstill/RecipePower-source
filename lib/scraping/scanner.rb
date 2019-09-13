# A Scanner object provides a stream of input strings
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

# Scan an input (space-separated) input stream. When the stream is exhausted, #more? returns false
class StrScanner < Scanner

  def initialize strings, pos=0
    # We include punctuation as a separate string per https://stackoverflow.com/questions/32037300/splitting-a-string-into-words-and-punctuation-with-ruby
    @strings = strings
    @pos = pos
    @length = @strings.count
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
