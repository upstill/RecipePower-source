require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'

# A Seeker is an abstract class for a subclass which presents a given item as a subrange of tokens from the given stream
class Seeker
  attr_accessor :stream, :token, :children
  attr_reader :range, :value
  delegate :size, :count, to: :range
  alias_method :length, :size # Number of tokens in the stream
  # Now #length, #size, and #count provide the number of tokens captured by this seeker

  delegate :nkdoc, to: :stream

  def initialize(stream = nil,
                 children: [],
                 range: nil,
                 pos: nil,
                 bound: nil,
                 token: nil)
    children.delete_if &:nil?
    if stream ||= children.first.stream
      @stream = stream
    else
      # It is an error to provide neither a stream nor children
      raise "Error initializing Seeker: no stream provided, either directly or via children"
    end

    @range =
        if range
          range
        else
          pos ||= children.map(&:pos).min || stream.pos
          bound ||= children.map(&:bound).max || stream.bound
          pos...bound
        end
    @token = token
    @children = children
    @stream.freeze
=begin
    if token && (head_stream.pos != tail_stream.pos) && Rails.env.test?
      puts "Seeker for :#{token} matched '#{to_s}'"
    end
=end
  end

  def clone_with attrvals={}
    rtnval = clone
    attrvals.each do |key, val|
      rtnval.instance_variable_set :"@#{key}", val
    end
    rtnval
  end

  # Return a Seeker for a failed parsing attempt
  # The head_stream and tail_stream will denote the range scanned
  # options:
  # :pos, :bound -- the places within the stream represented by the failed seeker
  # :range -- if given, overrides :pos and :bound
  # :optional, :enclose, :children -- flags for instance variables on the failed seeker
  def self.failed head_stream, options={}
  # def self.failed head_stream, tail_stream=nil, token= nil, options={}
    skr = self.new head_stream,
                   children: options[:children] || [],
                   range: options[:range],
                   pos: options[:pos] || head_stream.pos,
                   bound: options[:bound] || head_stream.pos
    skr.instance_variable_set :@failed, true
    skr.instance_variable_set :@optional, options[:optional]
    skr.instance_variable_set :@enclose, options[:enclose]
    skr.instance_variable_set :@token, options[:token] if options[:token]
    skr
  end

  def self.bracket_children *children
    ranges = children.flatten.compact.collect &:range
    (ranges.collect(&:begin).min)...(ranges.collect(&:end).max)
  end

  # Open a seeker to a wider context
  def with_stream stream
    self.stream = stream
    self
  end

  # Contents starting at the beginning
  def head_stream
    @stream.slice pos
  end

  # Contents between beginning and end
  def result_stream
    @stream.slice range
  end

  # The tail_stream is what comes after the content in the head stream
  def tail_stream
    @stream.slice bound
  end

  alias_method :scanner_beyond, :tail_stream
  alias_method :scanner_within, :head_stream

  def pos
    @range.begin
  end

  def pos=p
    p = 0 if p < 0
    @range = p...@range.end
  end

  def bound
    @range.end
  end

  def bound=b
    b = stream.bound if b > stream.bound
    @range = @range.first...b
  end

  # Find a place in the stream where we can match
  def self.seek stream, opts={}
    while stream.more?
      if sk = block_given? ? yield(stream) : self.match(stream, opts)
        return sk
      end
      stream = stream.rest
    end
  end

  # Seek to satisfy myself with the contents of the stream AT THIS POSITION.
  # Return: IFF there's a match, return an instance of the class, which denotes the original stream, and the
  #   rest of that stream, after parsing.
  def self.match stream, opts={}
  end

  # From a seeker tree, list descendants marked with a given token
  def find target=nil, &block
    if block_given? ? block.call(self) : (token == target)
      [ self ]
    elsif @children
      @children.map { |child| child.find target, &block }.flatten.compact
    else
      []
    end
  end

  def found_string token=nil
    find(token).first&.text
  end

  def found_strings token=nil
    find(token).collect &:text
  end

  # Root out the value associated with the token
  def find_value token=nil
    find(token).first&.value
  end

  def find_values token=nil
    find(token).map &:value
  end

  # Provide straight-up text of a seeker, with display options
  def text range=@range, nltr: false, trunc: nil, labelled: false
    str = stream.to_s range, nltr: nltr, trunc: trunc
    labelled ? ("[:#{@token}]" + str) : str
  end

  # Return all the text enclosed by the scanner i.e., from the starting point of head_stream to the beginning of tail_stream
  def to_s nltr: true, trunc: nil, labelled: true
    str = stream.to_s @range, nltr: nltr, trunc: trunc
    labelled ? ("[:#{@token}]" + str) : str
  end

  def done?
    bound >= stream.bound
  end

  # Judge the success of a seeker by its consumption of tokens AND the presence of children
  def empty?
    #(head_stream == tail_stream) &&
    (range.count == 0) &&
        @children&.empty?
  end

  def consumed?
    # Did the result consume any tokens?
    range.count > 0 # tail_stream.pos > head_stream.pos
  end

  # Expand the range to encompass another scanner's range
  def bounded_by scanner_or_bound_or_range
    #head_stream.encompass scanner
    # tail_stream.encompass scanner
    newbound = scanner_or_bound_or_range.is_a?(Integer) ?
                   scanner_or_bound_or_range :
                   scanner_or_bound_or_range.bound
    self.bound = newbound if newbound > bound
    self
  end

  def encompass_position newpos
    if newpos < pos
      self.pos = newpos
    elsif newpos > bound
      self.bound = newpos
    end
  end

  def traverse &block
    block.call self
    children&.each do |child|
      child.traverse &block
    end
  end

  # Enclose the tokens of the seeker, from beginning to end, in a tag with the given class
  def enclose tag='span'
    return unless @token
    # Check that some ancestor doesn't already have the tag
    if !head_stream.descends_from?(token: @token)
      head_stream.enclose_to bound, rp_elmt_class: @token, tag: tag, value: @value
    end
  end

  # Recursively modify the Nokogiri tree to reflect seekers
  def enclose_all parser: nil
    # The seeker reflects a successful parsing of the (subtree) scanner against the token.
    # Now we should modify the Nokogiri DOM to reflect the elements found
    traverse do |inner|
      if inner.token
        with_tag = parser&.tag_for_token(inner.token) || Parser.tag_for_token(inner.token)
        inner.enclose with_tag
      end
    end
  end

  # Match failed altogether
  def failed?
    @failed
  end

  def hard_fail?
    @failed && !@optional
  end

  def soft_fail?
    @failed && @optional
  end

  # Match succeeded; returns self for chaining purposes
  def success?
    self unless @failed # if @token || @children.present?
  end
  alias_method :if_succeeded, :'success?'

  def enclose? # Should the seeker be marked in an element, even without success?
    self if @enclose
  end
  alias_method :if_enclose, :'enclose?'

  def retain?
    self if !@failed || @enclose
  end
  alias_method :if_retain, :'retain?'

  # What's the next token to try? Three possibilities:
  # * The match succeeded: the next token is just after the match, i.e. tail_stream
  # * the match failed: the next token is the successor of the present token, i.e. head_stream.rest
  # * the match was optional: the tokens are consumed anyway: head_stream.rest at a minimum, possibly tail_stream
  def next context=nil
    subsq = if @failed
              tail_stream.pos > head_stream.pos ? tail_stream : head_stream.rest
            else # Success!
              tail_stream
            end
    context ? subsq.encompass(context) : subsq
  end

  def value_for token
    find(token).first&.text
  end

  # Provide a path and offset in the Nokogiri doc for the results of the parse
  def xbounds
    [ head_stream.xpath, tail_stream.xpath(true) ]
  end

  # Equality operator: is the given seeker redundant wrt us?
  def matches? other
    other.token == token &&
        other.bound >= pos && # It ends after we begin...
        other.pos < bound # ...and begins before we end
  end

  # Insert the given seeker(s) at an appropriate place in our tree
  def insert *insertions
    insertions.each do |to_insert|
      seeker_range = to_insert.range
      return true if range.cover?(seeker_range) && token == to_insert.token
      # First, expand our bounds to include its bounds
      @range = ([seeker_range.first, @range.first].min)...([seeker_range.last, @range.last].max)
      place = -1
      overlaps = @children.sort_by!(&:pos).select do |child| # Ensure that the children are ordered by position
        child_range = child.range
        place += 1 if seeker_range.begin < child_range.begin
        # Remember the child if its range overlaps with the seeker
        seeker_range.min < child_range.end && seeker_range.max > child_range.begin
      end
      if overlaps.empty?
        @children.insert place, to_insert
      else
        overlaps.first.insert to_insert # WHAT IF MORE THAN ONE OVERLAPS?
      end
    end
  end

  # Delete a child or descendant
  def delete child_or_descendant, recur: false
    if delix = children&.find_index { |child| child == child_or_descendant }
      children.delete_at delix
    elsif recur
      children&.each { |descendant| descendant.delete child_or_descendant, recur: true }
    end
  end

  # Expand the range of the seeker to include prior and subsequent newlines (for maximum enclosure)
  def open_range
    pos, bound = range.begin, range.end
    while pos > 0 && stream.tokens[pos-1] == "\n" do
      pos = pos - 1
    end
    while bound < stream.bound && stream.tokens[bound] == "\n" do
      bound = bound + 1
    end
    pos...bound
  end

end

# An Empty Seeker does nothing, and does not advance the stream
class EmptySeeker < Seeker
  def self.match stream, opts={}
    self.new stream
  end
end

# A Null Seeker simply accepts the next string in the stream and advances past it
class NullSeeker < Seeker
  def self.match stream, opts={}
    self.new stream, bound: stream.pos+1
  end
end

class StringSeeker < Seeker
  def self.match stream, options={}
    # TODO: the string should be tokenized according to tokenization rules and matched against a series of tokens
    self.new stream, bound: stream.pos+1, token: options[:token] if stream.peek == options[:string]
  end
end

class RegexpSeeker < Seeker
  def self.match stream, options={}
    self.new stream, bound: stream.pos+1, token: options[:token] if stream.peek&.match options[:regexp]
  end
end

# Top-level Seeker: for a recipe
# We seek individual elements of the recipe, and when found, enclose them in an Element of that class.
# The following is the grammar implemented by this search.
# The CSS class denoting such an element is given in parentheses. All such elements
# are also marked with the rp_elmt class
# TODO: Author, Yield
# Ingredient list (rp_inglist): rp_ingspec*  An ingredient list is a sequence of ingredient specs
# Ingredient spec (rp_ingspec): [rp_amount]? [rp_presteps] [rp_ingredient_tag | rp_ingalts]+ [rp_ingcomment]?
# Ingredient amount (rp_amount): rp_num | rp_unit | (rp_num rp_unit) [rp_altamt]?
# Alternate amount (rp_altamt): \(rp_amt\)
# Steps before measurement (rp_presteps): rp_process [{,'or'} rp_process]*
# Process (rp_process): <Tag type: :Process>
# Ingredient name (rp_ingredient_tag): <Tag type: :Ingredient>
# Alternate ingredients (rp_ingalts): rp_ingredient_tag [',|or' rp_inglist]+
# List of ingredients (rp_inglist): rp_ingredient_tag [',|and' rp_ingredient_tag]+
# Ingredient comment (rp_ingcomment): <content to end of line>
# Amount number (rp_num): defined by NumberSeeker
# Amount unit (rp_unit): <Tag type: :Unit>

# Seek an ingredient list
class IngredientListSeeker < Seeker

  # Seek by probing for an ingredient spec at each newline
  def self.seek stream, opts={}
    ils = []
    while stream.more?
      if stream.peek == "\n" # Only seek at line boundaries
        if is = IngredientSpecSeeker.match(stream.rest)
          ils << is
        end
      end
    end
    if ils.present?
      # Package the stream from the first spec to the last as the ingredient list
    end
  end

end

class RangeSeeker < Seeker
  def self.match stream, opts={}
    number_opts = opts.merge :token => :rp_num
    if match1 = NumberSeeker.match(stream, number_opts)
      ts = match1.tail_stream
      # Check for the token 'to' or '-' followed by a second number
      # If the second number is greater than the first, we've found our range
      if ts.peek&.match /(-|to)/i
        sep = $1
        match2 = NumberSeeker.match ts.rest, number_opts
        return nil if !match2 || (sep=='-' && match1.value >= match2.value) # Not a range but an integer plus fraction
        self.new stream, children: [ match1, match2 ], token: :rp_range
      end
    end
  end
end

# Seek a number at the head of the stream
class NumberSeeker < Seeker
  # A number can be a non-negative integer, a fraction, or the two in sequence
  def self.match stream, opts={}
    stream = stream.rest if stream.peek&.match /about/i
    len = case
          when self.num3(splitsies(stream, 3))
            3
          when self.num2(splitsies(stream, 2))
            2
          when self.num1(splitsies(stream, 1))
            1
          end
    if len
      result = self.new stream, bound: stream.pos+len, token: opts[:token]
      yield @@StrAfter if block_given? && @@StrAfter.present?
      # result.tail_stream = result.tail_stream.rest if result.tail_stream.peek&.match(',')
    end
=begin
    if Rails.env.test?
      if result
        puts "NumberSeeker found '#{result}' at '#{stream.to_s 100}'"
      else
        puts "NumberSeeker failed at '#{stream.to_s 100}'"
      end
    end
=end
    result
  end

  # Is the string either an integer or a fraction?
  def self.num1 str
    str&.match(/^\d*\/{1}\d*(\.\d*)?$|^\d*[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]?$/) ||
        (str && self.num_word(str))
  end

  def self.fraction str
    str&.match(/^\d*\/{1}\d*$|^[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]$/)
  end

  def self.whole_num str
    str&.match(/^\d*$/) || (str && self.num_word(str))
  end

  # Does the string have an integer followed by a fraction?
  def self.num2 str
    str&.match /^(\d+)[ -]((\d*\/{1}\d*|[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])$|^\d*)$/
  end

  # Does the string have an integer followed by a fraction?
  def self.num3 str, &block
    return if str.blank?
    strs = str.split /\ /
    if self.whole_num(strs.first) && (strs.count > 1)
        ((%q{ - and plus }.include?(strs[1]) && self.fraction(strs.last)) ||
            (strs[1] == '.' && self.whole_num(strs.last)))
    end
  end

  def self.num_word str
    (@NumWords ||= Hash[%w{ a an one two three four five six seven eight nine ten }.product([true])])[str.downcase]
  end

  # Convert a NumberSeeker string result to a number
  def value
    strs = text.split '-'
    num, denom = strs.pop.split '/'
    int = strs.present? ? strs.pop.to_i : 0
    return int+num.to_i if denom.blank?
    int + num.to_f / denom.to_f
  end

  private

  # Handle the case of, e.g., units attached to numbers (5oz.) by splitting out the non-numeric terminus
  # and placing it in a holding class variable @@StrAfter
  def self.splitsies stream, count
    str = stream.peek(count)
    if str&.match /^([\d¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞\s.\/-]+)(.*)$/
      str = $1
      @@StrAfter = $2
    else
      @@StrAfter = nil
    end
    str
  end
end

class TagSeeker < Seeker
  attr_reader :tagdata, :value

  def initialize stream, range, tagdata, token=nil
    super stream, range: range, token: token
    @value = tagdata[:name] if (@tagdata = tagdata).present?
  end

  def self.match stream, opts={}
    opts[:lexaur].chunk(stream) { |data, next_stream| # Find ids in the tags table
      # The Lexaur provides the data at sequence end, and the post-consumption stream
      scope = opts[:types] ? Tag.of_type(Tag.typenum opts[:types]) : Tag.all
      return unless tagdata = scope.limit(1).where(id: data).pluck( :id, :name).first
      tagdata = [:id, :name].zip(tagdata).to_h
      return self.new(stream, stream.pos...next_stream.pos, tagdata, opts[:token])
    }
    nil
  end
end

class UnitSeeker < TagSeeker
  attr_reader :tagdata, :value

=begin
  def initialize(stream, next_stream, tagdata, token=nil)
    super stream, next_stream, token
    @value = tagdata[:name] if (@tagdata = tagdata).present?
  end
=end

  # A unit tag may have an embedded unit qualifier
  def self.match stream, opts={}
    qualifier = nil
    skipper = -> (stream) {
      stream
=begin
      result = opts[:parser]&.match(:rp_altamt, stream: stream)
      if result.success?
        qualifier = result
        result.tail_stream
      else
        stream
      end
=end
    }
    opts[:lexaur].chunk(stream, skipper: skipper) { |data, next_stream| # Find ids in the tags table
      # The Lexaur provides the data at sequence end, and the post-consumption stream
      scope = opts[:types] ? Tag.of_type(Tag.typenum opts[:types]) : Tag.all
      return unless tagdata = scope.limit(1).where(id: data).pluck( :id, :name).first
      tagdata = [:id, :name].zip(tagdata).to_h
      return self.new(stream, next_stream, tagdata, opts[:token])
    }
    nil
  end
end

# Conditions are a list of { process, }*. Similarly for Ingredients
class TagsSeeker < Seeker
  attr_accessor :operand

  def initialize head_stream, token = nil, children=[], operand: nil
    super head_stream, children: children, token: token
    @operand = operand
  end

  def self.match stream, opts={}
    children = []
    rptype = { 'Ingredient' => :rp_ingredient_tag, 'Condition' => :rp_condition_tag }[Tag.typename opts[:types]]
    scope = opts[:types] ? Tag.of_type(Tag.typenum opts[:types]) : Tag.all
    operand = ''
    opts[:lexaur].distribute(stream) do |data, stream_start, stream_end, op|
      operand = op if op != ','
      # The Lexaur provides the data at sequence end, and the post-consumption stream
      if tagdata = scope.limit(1).where(id: data).pluck( :id, :name).first
        children << TagSeeker.new(stream_start, stream_start.pos...stream_end.pos, [:id, :name].zip(tagdata).to_h, rptype)
      end
    end
    if children.present?
      children = children.sort_by &:pos
      self.new stream, opts[:token], children, operand: operand
    end
  end

=begin
  def self.match stream, opts
    # Get a series of zero or more tags of the given type(s), each followed by a comma and terminated with 'and' or 'or'
    if ns = TagSeeker.match(stream, opts.slice( :lexaur, :types))
      sk = self.new stream, ns.tail_stream, ns
      case ns.tail_stream.peek
      when 'and', 'or'
        # We expect a terminating condition
        if ns2 = TagSeeker.match(ns.tail_stream.rest, opts.slice(:lexaur, :types))
          sk.tag_seekers << ns2
          sk.tail_stream = ns2.tail_stream
        else
          return nil
        end
      when ','
        if further = self.match(ns.tail_stream.rest, opts)
          sk.tag_seekers += further.tag_seekers
          sk.tail_stream = further.tail_stream
        end
      end
      return sk
    end
  end
=end
end

# An Amount is a number followed by an optional amount, optionally followed by an alternative amount in parentheses
class AmountSeeker < Seeker

  attr_reader :num, :unit, :alt_num, :alt_unit

  def initialize stream, num, unit
    super stream, range: Seeker.bracket_children((num if num.is_a?(Seeker)), unit)
    @num = num
    @unit = unit
    @token = :rp_amt
  end

  def self.match stream, opts = {}
    original_stream = stream.clone
    stream = stream.rest if stream.peek&.match /about/i
    pos = stream.pos
    unit = nil
    num = NumberSeeker.match(stream) { |remainder|
      # A unit may follow the number within the same token
      if unit = TagSeeker.match(StrScanner.new([ remainder ]), opts.slice(:lexaur).merge(types: 5))
        unit.stream, unit.pos, unit.bound = stream, stream.pos, stream.pos+1
      end
    }
    if num
      unit ||= TagSeeker.match num.tail_stream, opts.slice(:lexaur).merge(types: 5)
      return if opts[:full_only] && !unit
    elsif stream.peek&.match(/(^\d*\/{1}\d*$|^\d*[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]?)-?(\w*)/) &&
        (($1.present? && $2.present?) || !opts[:full_only])
      num = $1.if_present || '1'
      unit = TagSeeker.match StrScanner.new([$2]), opts.slice(:lexaur).merge(types: 5)
      return unless unit
      unit.stream, unit.pos, unit.bound = stream, stream.pos, stream.pos+1
    else
      return
    end
    self.new original_stream, num, unit
  end

end

# A FullAmountSeeker requires BOTH number and unit
class FullAmountSeeker < AmountSeeker
  def self.match stream, opts={}
    super stream, opts.merge(:full_only => true)
  end

end

# Check for a matched set of parentheses in the stream and call a block on the contents
class ParentheticalSeeker < Seeker
  def self.matcher ch
    case ch
    when '('
      ')'
    when '['
      ']'
    end
  end

  def self.match stream, opts={}
    if match = ParentheticalSeeker.matcher(stream.peek)
      stack = []
      rest = stream.clone.rest
      # Consume the opening paren
      # Look for the closing paren
      while ch = rest.peek do
        if newmatch = ParentheticalSeeker.matcher(ch)
          stack.push match
          match = newmatch
        elsif ch == match
          if (match = stack.pop).nil?
            # Done!
            yield(stream.rest.except rest) if block_given?
            return self.new stream, token: :rp_parenthetical, bound: rest.pos+1
          end
        end
        rest.first
      end
    end
  end
end

class ConditionsSeeker < TagsSeeker
  def self.match stream, opts
    super stream, opts.merge(types: 22)
  end
end

class IngredientsSeeker < TagsSeeker
  def self.match stream, opts
    super stream, opts.merge(types: 4, token: :rp_ingalts)
  end
end

class IngredientSpecSeeker < Seeker
  attr_reader :amount, :condits, :ingreds

  def initialize stream, range, amount, condits, ingreds
    super stream, range: range
    @amount, @condits, @ingreds = amount, condits, ingreds
  end

  def self.match stream, opts={}
    original_stream = stream.clone
    if amount = AmountSeeker.match(stream, opts)
      puts "Found amount #{amount.num} #{amount.unit}" if Rails.env.test?
      stream = amount.tail_stream
    end
    if condits = ConditionsSeeker.match(stream, opts)
      stream = condits.tail_stream
    end
    if ingreds = IngredientsSeeker.seek(stream, opts)
      self.new original_stream, ingreds.range, amount, condits, ingreds
    end
  end
end

=begin
require "candihash.rb"

class Seeker < Object

  # Save the Seeker data into session store
  def store
    # Serialize structure consisting of tagstxt and specialtags
    savestr = YAML::dump( datastore ) 
    back = YAML::load(savestr)
    savestr
  end
  
private

  def page_length
    25
  end

  # class-specific data storage
  def datastore
    { 
      :tagstxt => (@tagstxt || ""), 
      :tagtype => @tagtype, 
      :page => @cur_page || 1 # , :items_per_page => @items_per_page
    }
  end
  
  def dataload datastr
    prior = !datastr.blank? && YAML::load(datastr)
    if prior
      @tagstxt = prior[:tagstxt] || ""
      @tagtype = prior[:tagtype]
      @cur_page = prior[:page] || 1
      # @items_per_page = prior[:items_per_page] ? prior[:items_per_page].to_i : @@page_length
    else
      @tagstxt = "" 
      @tagtype = nil
      @cur_page = 1
      # @items_per_page = @@page_length
    end
    @items_per_page = page_length
    prior || {}
  end
  
  def affiliate browser = nil, params = nil
    @affiliate ||= model_class.all
  end
public

  def initialize user, browser = nil, datastr = nil, params = nil
    @user = user
    # Retrieve prior data from datastr if provided
    dataload datastr
    # The affiliate is generally a scope, but in the case of the content browser, it's the browser itself
    affiliate browser, params # We leave it to subclasses to define a different affiliate from params
    # Params for tagstxt and cur_page will override the prior info
    if params
      @items_per_page = params[:items_per_page].to_i if params[:items_per_page]
      if params[:tagstxt]
        @tagstxt = params[:tagstxt]
        @tags = nil
        params[:cur_page] = 1
      end
      if ttstr = params[:tagtype]
        @tagtype = ttstr.empty? ? nil : ttstr.to_i
      end
      if page = params[:cur_page]
        self.cur_page = page.to_i
      elsif params[:next_page]
        params[:cur_page] = self.cur_page + 1
      end
    end
    if params && params[:cur_page]
      self.cur_page = params[:cur_page].to_i
    end
  end

  def query_path
    "/#{entity_name.pluralize}"
  end
  
  def model_class
    entity_name.capitalize.constantize
  end
  
  def convert_ids list, keep_ordering=false
    records = model_class.find(list)
    if keep_ordering
      records = records.group_by(&:id)
      list.map { |id| records[id].first }
    else
      records
    end
  end
  
  def list_type
    entity_name.to_sym
  end
  
  def entity_name
    self.class.to_s.sub(/Seeker$/, '').downcase
  end
  
  def table_header
    entity_name.capitalize.pluralize
  end
  
  def tagstxt()
    @tagstxt
  end
  
  def tagtype
    @tagtype
  end
  
  def guide
    # Describe this seeker for presentation to the user
    (affiliate && @affiliate.respond_to?(:selected) && @affiliate.selected) ? @affiliate.selected.guide : "This is your friendly seeker"
  end
  
  def hints
    (affiliate && @affiliate.respond_to?(:selected) && @affiliate.selected) ? @affiliate.selected.hints : "Handy Hints Here"
  end
  
  # Accept new tags text, bust the cache, and return the new set of tags
  def tagstxt=(txt)
    # We either use the current tagstxt or the parameter, updating the tagstxt as needed
    @tagstxt = txt
    @tags = nil
    tags
  end
  
  # Update the contents and return true OR enqueue the update job and return false
  def refresh
    # By default, we're ready to go, but the affiliate may have to fire off an update job in background
    affiliate.respond_to?(:refresh) ? affiliate.refresh : true
  end
  
  def updated_at
    affiliate.respond_to?(:updated_at) && affiliate.updated_at
  end
  
  # Use the 'querytags' string (in actuality a string provided by the unconstrained tags editor) to extract
  # a set of tag tokens. The elements of the comma-separated string are either 1) a positive integer, representing
  # a tag in the dictionary, or 2) an arbitrary other string on which to query.
  # The tags method converts the latter into a transitory tag with a negative value, an index into an internally-stored
  # array of pseudo-tags
  def tags
    return @tags if @tags # Use cache, if any
    newspecial = {}
    oldspecial = @specialtags || {}
    # Accumulate resulting tags here:
    @tags = []
    @tagstxt.split(",").each do |e| 
      e.strip!
      if(e=~/^\d*$/) # numbers (sans quotes) represent existing tags that the user selected
        @tags << Tag.find(e.to_i)
      elsif e=~/^-\d*$/  # negative numbers (sans quotes) represent special tags from before
        # Re-save this one
        tag = Tag.new(name: (newspecial[e] = oldspecial[e]))
        tag.id = e.to_i
        @tags << tag
      else
        # This is a new special tag. Convert to an internal tag and add it to the cache
        name = e.gsub(/\'/, '').strip
        unless tag = Tag.strmatch( name, { matchall: true, uid: @userid }).first
            tag = Tag.new( name: name )
            tag.id = -1
            # Search for an unused id
            while(newspecial[tag.id.to_s] || oldspecial[tag.id.to_s]) do
                tag.id = tag.id - 1
            end
            newspecial[tag.id.to_s] = tag.name
        end
        @tags << tag
      end
    end
    # Have to revise tagstxt to reflect special tags because otherwise, IDs will get 
    # revised on the next read from DB
    @tagstxt = @tags.collect { |t| t.id.to_s }.join ','
    @specialtags = newspecial
    @tags
  end
  
  # Are there any recipes waiting to come out of the query?
  def empty?
    result_ids.empty?
  end
  
  def npages
    (result_ids.count+(@items_per_page-1))/@items_per_page
  end
  
  def cur_page
    @cur_page
  end
  
  def cur_page=(pagenum)
    @cur_page= pagenum
  end
  
  # Return a list of results based on the query tags and the paging parameters
  def results_paged
    npg = npages
    ids = result_ids 
    first = 0
    ixbound = ids.count 
    if npg > 1
      # Clamp current page to last page
      self.cur_page = npg if cur_page > npg
      # Now get index bounds for the records on the page
      first = (cur_page-1)*@items_per_page
      last = first+@items_per_page
      ixbound = last if ixbound > last
    end
    convert_ids ids[first...ixbound]
  end
  
  # Return the list of ids matching the tags, by calling an application method
  def result_ids
  	return @results if @results # Keeping a cache of results
    if tags.empty?
      @results = affiliate.map(&:id)
    else
      # We purge/massage the list only if there is a tags query here
      # Otherwise, we simply sort the list by mod date
      # Convert candidate array to a hash recipe_id=>#hits
      candihash = Candihash.new affiliate.map(&:id)
      apply_tags candihash
      # Convert back to a list of results
      @results = candihash.results.reverse
  	end
  end

  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    report = "It looks like there aren't any #{entity_name.pluralize} that match your search"
    case tags.count
    when 0
      sug = nil
    when 1
      sug = "a different tag or no tag at all up there"
    else
      sug = "changing and/or deleting tags up there"
    end
    report+((sug && ".<br>You might try #{sug}.") || ".")
  end

end

class ContentSeeker < Seeker

  delegate :convert_ids, :timestamp, :list_type, :to => :"@affiliate"
  
  def affiliate browser = nil, params = nil
    @affiliate ||= browser
  end
  
  # Get the results of the current query from the affiliated browser.
  def result_ids
    affiliate.result_ids tags
  end
  
  def query_path
    "/collection"
  end
  
begin

  def cur_page=(pagenum)
    affiliate.cur_page=( pagenum) if affiliate
  end

end
  
  # If the entity has returned no results, suggest what the problem might have been
  def explain_empty
    explanation = affiliate.explain_empty tags
    (explanation[:sug] ? explanation[:report]+"<br>You might try #{explanation[:sug]}." : explanation[:report])+"<br>#{explanation[:hint]}"
  end

  private
  def page_length
    10
  end

end

class UserSeeker < Seeker

  def datastore
    super.merge is_channel: (@is_channel || false)
  end
  
  def dataload datastr
    data = super
    @is_channel = data[:is_channel] || false
  end

  def affiliate browser=nil, params=nil
    @is_channel = (params[:channel]=="true") if params && params[:channel]
    unless @affiliate
      if @is_channel
        @affiliate = User.where("channel_referent_id > 0")
      else
        @affiliate = User.where("channel_referent_id = 0 AND sign_in_count > 0")
      end
      excluded_ids = @user.followee_ids + [@user.id, 4, 5] # Don't list guest, super, or the current user
      @affiliate = @affiliate.where("id not in (?) AND private != true", excluded_ids) unless [1, 3].include?(@user.id) # Show Max and Steve everything
      @affiliate = @affiliate.collect { |u| [ u, u.recipes_collection_size ] }.sort { |u1, u2| u2.last <=> u1.last }.map(&:first)
    end
    @affiliate
  end

  def query_path
    "/users?channel="+@is_channel.to_s
  end
  
  def entity_name
    @is_channel ? "channel" : "user"
  end
  
  def table_header
    @is_channel ? "Available Channels" : "Possible Friends"
  end

  # Convert ids into User records, preserving the order of the list
  def convert_ids list
    records = User.find(list).group_by(&:id)
    list.map { |id| records[id].first }
  end
  
  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    neighbors = TagServices.lexical_similars(tags)
    weightings = TagServices.semantic_neighborhood(tag_ids = neighbors.map(&:id), 0.8)
    # Get tags that aren't in the original set
    (tags + Tag.where(id: weightings.keys - tag_ids)).each do |tag| 
      user_ids = tag.user_ids
      candihash.apply user_ids, weightings[tag.id] if tag.id > 0
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      users = affiliate.where("username ILIKE ?", "%#{tag.name}%")
      candihash.apply users.map(&:id), 1.0
      users = affiliate.where("about ILIKE ?", "%#{tag.name}%")
      candihash.apply users.map(&:id), 1.0
    end
  end
  
end

class ReferenceSeeker < Seeker
  
  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("url LIKE ?", "%#{tag.name}%").map(&:id)
      constraints = @tagtype ? { tagtype: @tagtype } : {}
      # collect all the references of all the referents of all matching tags
      list = Tag.strmatch(tag.name).collect { |tag| tag.referents }.flatten
      list = list.collect { |referent| referent.reference_ids }
      candihash.apply list.flatten.uniq
    }
  end
end

class SiteSeeker < Seeker

  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("site ILIKE ?", "%#{tag.name}%").map(&:id)
      # Find lexically-related tags of Source type and see if they point to sites
      # Find sites that have been tagged similarly
    }
  end
end

class TagSeeker < Seeker

  # Get the results of the current query.
  def result_ids
  	return @results if @results # Keeping a cache of results
    case tags.count
    when 0
      @results = (@tagtype ? affiliate.where(tagtype: @tagtype) : affiliate).map(&:id)
    when 1
      constraints = @tagtype ? { tagtype: @tagtype } : {}
      @results = Tag.strmatch(tags.first.name, constraints).map(&:id)
    else
      super
  	end
  end
  
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag| 
      # candihash.apply tag.recipe_ids if tag.id > 0 # A normal tag => get its recipe ids and apply them to the results
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply Tag.strmatch(tag.name, tagtype: tag.tagtype).map(&:id)
    }
  end
end

class FeedSeeker < Seeker

  def datastore
    super.merge all_feeds: (@all_feeds || false)
  end

  def dataload datastr
    data = super
    @all_feeds = data[:all_feeds] || false
  end

  def affiliate browser=nil, params=nil
    @all_feeds ||= params && params[:all_feeds]
    @affiliate ||= @all_feeds ? Feed.all : Feed.where(:approved => true)
  end

  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag|
      semantic_list = Feed.where(site_id: Site.where(referent_id: tag.referent_ids).map(&:id)).map(&:id)
      candihash.apply semantic_list
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("description ILIKE ?", "%#{tag.name}%").map(&:id)
      candihash.apply affiliate.where("title ILIKE ?", "%#{tag.name}%").map(&:id)
    }
  end
end

class ListSeeker < Seeker

  def affiliate browser=nil, params=nil
    @affiliate ||= List.all
  end

  # Get the results of the current query.
  def apply_tags(candihash)
    # Rank/purge for tag matches
    tags.each { |tag|
      # Get candidates by matching the tag's name against recipe titles and comments
      candihash.apply affiliate.where("description ILIKE ?", "%#{tag.name}%").map(&:id)
      candihash.apply affiliate.where("title ILIKE ?", "%#{tag.name}%").map(&:id)
    }
  end
end
=end
