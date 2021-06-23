require 'recipe.rb'
require 'recipe_page.rb'
class ParsingServices
  attr_accessor :entity, # Object (ie., Recipe or RecipePage) to be parsed
                :parser, # Parser, possibly with modified grammar, to be employed
                :seeker  # Resulting tree of seeker results

  def initialize entity=nil, options={}
    @entity = entity
    @lexaur = options[:lexaur]
    @grammar = options[:grammar]
  end

  # annotate: apply a parsing token to the given html, using the XML paths denoting the selection
  def annotate html, token, anchor_path, anchor_offset, focus_path, focus_offset
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    # Do QA on the parameters
    if anchor_path.present? && focus_path.present? && anchor_offset.to_i && focus_offset.to_i
      newnode = nokoscan.tokens.enclose_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, rp_elmt_class: token, tag: Parser.tag_for_token(token)
      csspath = newnode.css_path
      xpath = Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
      # Test the revised document: it should not change when converted to html and back into Nokogiri
      if Nokogiri::HTML.fragment(nkdoc.to_s).to_s != nkdoc.to_s
        raise "Annotation failed: new doc. changes on cycling through Nokogiri."
      end
      [ nkdoc.to_s, xpath ]
    end
  end

  def self.extract_via_path html, path
    nkdoc = Nokogiri::HTML.fragment html
    # Get the target element
    nkdoc.xpath(path.downcase)&.first # Extract the token at that element
  end

  # parse_on_path: assert the grammar on the element denoted by the path, getting the target token from the element
  def self.parse_on_path html, path
    elmt = self.extract_via_path html, path
    nkdoc = elmt.ancestors.last
    nokoscan = NokoScanner.new elmt
    if (class_attr = elmt.attribute('class')) &&
        (token = class_attr.to_s.split.find { |cl| cl.match(/^rp_/) && cl != 'rp_elmt' }) &&
        token.present?
        # For direct Tag terminals, short-circuit the parsing process with a tag lookup
      if tagtype = Parser.tagtype(token) # This token calls for a tag
        # Go directly to tag lookup in the database
        typenum = Tag.typenum tagtype
        tagstr = nokoscan.to_s
        if Tag.strmatch(tagstr, tagtype: typenum, matchall: true).empty? # No such tag found
          # If no such tag exists, we need a decision from the user whether to
          # 1) assert the tag into the database, or
          # 2) identify an existing tag to which it corresponds.
          # To get a ruling, we present a dialog which asks the question, possibly getting a tag to use.
          # If 1), life goes on and the unparsed tag will be asserted when the page is finally accepted
          # If 2), upon choosing a tag, the submission specifies a value that's asserted as above
          # In any event, we let the calling controller handle it
          yield typenum, tagstr if block_given?
        end
      else
        @parser = Parser.new nokoscan, @lexaur
        seeker = @parser.match token.to_sym
        seeker = second_guess seeker, @parser, token.to_sym # Renegotiate for the contents of the results
        enclose_results seeker, parser: @parser
      end
    end
    nkdoc.to_s
  end

  # After a seeker has come back from parsing with a failure, deploy strategies for re-parsing
  def self.second_guess seeker, parser, token
    # For any given token, assess the result and take any needed steps to correct it.
    grammar_mods = nil
    case token
    when :rp_inglist, :rp_recipe
      # Does the list have any :ingline's? Try parsing different
      if seeker.find(:rp_ingline).empty?
        grammar_mods = { :rp_ingline => { :in_css_match => nil, :inline => true } }
      end
    end
    if grammar_mods
      parser.push_grammar grammar_mods
      # enclose_results seeker, parser: parser
      # The nkdoc is now modified and ready to re-parse
      seeker = parser.match token.to_sym
      parser.pop_grammar
    end
    seeker
  end

  def self.parse_from_string input, token, site: nil, lexaur: nil
    parser = Parser.new input, lexaur
    match = parser.match token
    match = second_guess match, parser, token.to_sym # Renegotiate for the contents of the results
    match
  end

  def self.enclose_results seeker, parser: nil
    if seeker.success?
      seeker.enclose_all parser: parser
      seeker.head_stream.nkdoc.to_s
    end
  end

  # Put the content through the mill, annotate it with the parsing results, and return HTML for the whole thing
  def parse_and_annotate content
    if seeker = parse(content)
      [:rp_ingline].each do |token|
        Rails.logger.debug "-------------- #{token} ---------------"
        seekers = seeker.find(token)
        seekers.each { |seeker|
          Rails.logger.debug seeker
        }
      end
      ParsingServices.enclose_results seeker, parser: @parser
      seeker.head_stream.nkdoc.to_s
    end
  end

  # Extract information from an entity (Recipe or RecipePage)
  def parse content=nil
    case @entity
    when Recipe
      parse_recipe content || @entity.content
    when RecipePage
      parse_recipe_page content || @entity.content
    else
      err_msg = "Illegal attempt to parse #{@entity.class} object"
      @entity.errors.add :url, err_msg
      raise err_msg
    end
  end

  # Report out the parsing results for the given elements of the grammar
  # An empty specification means to report out all elements of the grammar
  # A hash with an :except key may be used to exclude certain tokens
  def report_for *tokens, &block
    def report token, seekers, &block
      if seekers.present?
        block_given? ? block.call(seekers) : "Found #{Parser.token_to_title(token).pluralize(seekers.count)} '#{seekers.map(&:to_s).join('\', \'')}'"
      else
        "No #{Parser.token_to_title(token).pluralize 0}"
      end
    end
    glean_tokens(tokens).collect { |token| report token, @seeker.find(token), &block }
  end

  def do_for *tokens, &block
    return unless @seeker
    glean_tokens(tokens).each do |token|  # For each specified token
      @seeker.find(token).each do |seeker| # For each result under that token
        with_seeker(seeker) do |parser| # Call the given block with a parser using that seeker
          block.call parser, token
        end
      end
    end
  end

  def has? token
    @seeker&.find(token).present?
  end

  def value_for token
    @seeker&.find(token).first&.to_s
  end

  # Provide a path and offset in the Nokogiri doc for the results of the parse
  def xbounds
    @seeker ? [ @seeker.head_stream.xpath, @seeker.tail_stream.xpath(true) ] : []
  end

private

  def parse_recipe_page content
    # grammar[:rp_recipelist][:start] = { match: //, within_css_match: 'h2' }
    @parser = Parser.new content, @lexaur, @entity.site.grammar_mods
    @seeker = parser.match :rp_recipelist
    @seeker = ParsingServices.second_guess @seeker, @parser, :rp_recipelist # Renegotiate for the contents of the results
  end

  def parse_recipe content
    @parser = Parser.new content, @lexaur, @entity.site.grammar_mods
    @seeker = @parser.match :rp_recipe
    @seeker = ParsingServices.second_guess @seeker, @parser, :rp_recipe # Renegotiate for the contents of the results
  end

  # Execute a query, etc., on a seeker other than the last parsing result (perhaps a subtree)
  def with_seeker seeker, &block
    dupe = self.clone
    dupe.seeker = seeker
    block.call dupe
  end

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
