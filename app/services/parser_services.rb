require 'recipe.rb'
require 'scraping/parser.rb'
require 'recipe_page.rb'
class ParserServices
  attr_reader :parsed, :scanned, # Trees of seeker results resulting from parsing and scanning, respectively
              :grammar_mods, # Modifications to be used on the parser beforehand
              :input,
              :nokoscan # The scanner associated with the current input

  delegate :nkdoc, to: :nokoscan
  delegate :'success?', :find, :hard_fail?, :find_value, :value_for, :xbounds, to: :parsed

  def initialize entity: nil, token: nil, input: nil
    self.entity = entity # Object (ie., Recipe or RecipePage) to be parsed
    self.token = token
    self.input = input
  end

=begin
Here is where all dependencies in the parser are expressed: dependent variables are cleared
when the entities on which they depend are expressed.
The dependencies are as follows:
@parsed, @scanned
  @token
  @parser
    @input
      @entity
    @grammar_mods
      @entity
    @lexaur
...therefore, when any of them are set, their dependents must be nulled out (recursively)
=end

  # Apply the parser to a NokoScanner
  def parser
    @parser ||= Parser.new nokoscan, @lexaur, @grammar_mods
  end

  def parser=p
    if p != @parser
      @parsed = nil
      @scanned = nil # New parser invalidates :parsed and :scanned
    end
    @parser = p
  end

  def lexaur=l
    self.parser = nil if l.nil? || l != @lexaur
    @lexaur = l
  end

  def grammar_mods=gm
    self.parser = nil if gm.nil? || gm != @grammar_mods # Start all over again
    @grammar_mods = gm
  end

  def input
    @input || @entity.content
  end
  
  # Setting @input invalidates @nokoscan
  def input=ct
    @nokoscan = nil if ct.nil? || ct != @input
    @input = ct
  end

  def entity=e
    self.grammar_mods = e&.site&.grammar_mods
    self.input = nil if e.nil? || e != @entity # Assert grammar_mods, if any
    @entity = e
  end

  # What is the default top-level ask for the entity?
  def token
    @token ||=
        case @entity
        when Recipe
          :rp_recipe
        when RecipePage
          :rp_recipelist
        else
          err_msg = "Illegal attempt to parse #{@entity&.class || 'without associated'} object"
          @entity.errors.add :url, err_msg if @entity
          raise err_msg
        end
  end

  def token=tk
    @parsed = @scanned = nil if tk != @token || tk.nil?
    @token = tk
  end

  # The NokoScanner is derived from the designated input or, if no input, the entity's content
  # per NokoScanner initialization, @input may be any of a string, scanner, tokens or Nokogiri document
  def nokoscan
    @nokoscan ||=
        case @input
        when NokoScanner
          @input
        when nil # Fall back on the entity's input
          NokoScanner.new @entity&.content
        else # Let NokoScanner sort it out
          NokoScanner.new @input
        end
  end

=begin
  # Divide a line by commas and 'and', parsing the sections into instances of the token
  def chunk_line token: :rp_ingline
    nks = nokoscan # Save for later
    results = nks.split(',').collect { |chunk| parse input: chunk, token: token }
    # If the last clause contains multiple 'and' tokens, split across each one in turn
    turns = results.last.head_stream.split('and').delete_if &(:blank?)
    pairs = []
    turns[0...-1].each_index do |i|
      pairs.push [ parse(input: turns[0].encompass(turns[i]), token: token),
                   parse(input: turns[(i+1)].encompass(turns[-1]), token: token) ]
    end
    if pairs.first&.all? &:'success?'
      results.pop
      results += pairs.first
    end
    self.input = nks
    @parsed = Seeker.new nks, results.last.tail_stream, token, results
  end
=end

  # Extract information from an entity (Recipe or RecipePage) or presented input
  def parse options={}
    self.input = options[:input] if options.key?(:input)
    self.token = options[:token] if options.key?(:token)
    annotate = options.delete :annotate
    seeking = options[:seeking] || [ :rp_title, :rp_inglist, :rp_instructions ]
    # There must be EITHER input or an entity specified
    if input.nil? && entity.nil?
      raise "Error in ParserServices#parse: must provide EITHER input or an entity"
    end
    # Likewise, either a token or an entity must be specified
    if token.nil? && entity.nil?
      raise "Error in ParserServices#parse: must provide EITHER a token or an entity"
    end

    @parsed = parser.match token, stream: nokoscan
    @parsed.enclose_all parser: parser if annotate && @parsed&.success?

    # Perform the scan only if seeking elements aren't found in the parse
    @scanned = parser.scan # if seeking.any? { |token| !@parsed&.find(token).first }
    @scanned.enclose_all parser: parser if annotate && @scanned&.success?

    @parsed&.success? || @scanned&.success?
  end

  def content
    nkdoc&.to_s
  end

  # Put the input through the mill, annotate it with the parsing results, and return HTML for the whole thing
=begin
annotate is now an option to #parse
  def annotate
    @parsed.enclose_all parser: parser if @parsed&.success?
    @scanned.enclose_all parser: parser if @scanned&.success?
    return nkdoc.to_s
  end
=end

  def annotate_selection token, anchor_path, anchor_offset, focus_path, focus_offset
    # Do QA on the parameters
    if anchor_path.present? && focus_path.present? && anchor_offset.to_i && focus_offset.to_i
      newnode = nokoscan.tokens.enclose_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, rp_elmt_class: token, tag: parser.tag_for_token(token)
      csspath = newnode.css_path
      xpath = Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
      # Test the revised document: it should not change when converted to html and back into Nokogiri
      if Nokogiri::HTML.fragment(nkdoc.to_s).to_s != nkdoc.to_s
        raise "Annotation failed: new doc. changes on cycling through Nokogiri."
      end
      [ nkdoc.to_s, xpath ]
    end
  end

  # Get content from the Nokogiri document by path
  def extract_via_path path
    # Get the target element
    nkdoc.xpath(path.downcase)&.first # Extract the token at that element
  end

  # parse_on_path: assert the grammar on the element denoted by the path, getting the target token from the element
  def parse_on_path path
    elmt = extract_via_path path
    #@nkdoc = elmt.ancestors.last
    # nokoscan = NokoScanner.new elmt
    if (tokens = nknode_rp_classes(elmt)).present?
      # For direct Tag terminals, short-circuit the parsing process with a tag lookup
      if tagtype = tokens.map { |token| Parser.tagtype(token) }.compact.first # This token calls for a tag
        # Go directly to tag lookup in the database
        typenum = Tag.typenum tagtype
        tagstr = elmt.text
        if extant = Tag.strmatch(tagstr, tagtype: typenum, matchall: true).first
          elmt['value'] = extant.name
        else # No such tag found
          # We need a decision from the user whether to
          # 1) assert the tag into the database, or
          # 2) identify an existing tag to which it corresponds.
          # To get a ruling, we present a dialog which asks the question, possibly getting a tag to use.
          # If 1), life goes on and the unparsed tag will be asserted when the page is finally accepted
          # If 2), upon choosing a tag, the submission specifies a value that's asserted as above
          # In any event, we let the calling controller handle it
          yield typenum, tagstr if block_given?
        end
      else
        parse input: elmt, token: tokens.first
        parsed.enclose_all parser: parser
      end
    end
    nkdoc.to_s
  end

  def do_for *tokens, &block
    return unless @parsed || @scanned
    glean_tokens(tokens).each do |token|  # For each specified token
      (@parsed.find(token) + @scanned.find(token)).each do |seeker| # For each result under that token
        block.call seeker, token
      end
    end
  end

  def found_for token, as: nil
    return [] if token.nil? || (seekers = @parsed.find(token) + @scanned.find(token)).empty?
    # Convert the results according to :as specifier
    return seekers unless as
    found = seekers.map do |seeker|
      case as
      when :amountstring
        [seeker.find(:rp_num_or_range)&.to_s, seeker.find(:rp_unit)].compact.join ' '
      when :numrange
        num_or_range = seeker.find(:rp_num_or_range).first.to_s
        nums = num_or_range.
            split(/-|to/).
            map(&:strip).
            keep_if { |substr| substr.match /^\d*$/ }.
            map &:to_i
        (nums.first)..(nums.last) if nums.present?
      when :timerange
        next unless timestr = seeker.find(:rp_time).first&.to_s
        secs =
        if timestr.match(/(\d+)\s+(\w+)/)
          num = $1.to_i
          unit = $2
          case unit
          when /minute/
            num * 60
          when /hour/
            num * 3600
          end
        elsif timestr.match /(\d+):(\d+)/
          ($1 * 60 + $2) * 60
        end
        (secs..secs) if secs
      end
    end
    found.compact
  end

  private

  def glean_tokens token_list
    exceptions =
        if exceptions_index = token_list.index { |v| v.is_a? Hash } # returns index if block is true
          [token_list.delete_at(exceptions_index)[:except]].flatten # ...allowing single token or array
        else
          []
        end
    token_list = @parser.tokens if token_list.empty?
    token_list - exceptions
  end

end
