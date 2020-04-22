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
      newnode = nokoscan.tokens.enclose_by_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, classes: token, tag: Parser.tag_for_token(token)
      csspath = newnode.css_path
      xpath = Nokogiri::CSS.xpath_for(csspath[4..-1]).first.sub(/^\/*/, '') # Elide the '? > ' at the beginning of the css path and the '/' at beginning of the xpath
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
      @parser = Parser.new nokoscan, @lexaur || Lexaur.from_tags
      token = token.to_sym
      seeker = @parser.match token
      if seeker.children&.first
        seeker.enclose_all
        return nkdoc.to_s
      end
      # Parse failed. Now we do token-dependent processing to handle the problem
      grammar_entry = @parser.grammar[token]
      # If this token is meant to represent a tag in the database...
      if grammar_entry.is_a?(Hash) && tagtype = grammar_entry[:tag]
        # We need a decision from the user, whether to
        # 1) assert the tag into the database, or
        # 2) identify an existing tag to which it corresponds.
        # To get a ruling, we present a dialog which asks the question, possibly getting a tag to use.
        # If 1), life goes on and the unparsed tag will be asserted when the page is finally accepted
        # If 2), upon choosing a tag, the submission specifies a value that's asserted as above
        # In any event, we let the calling controller handle it
        yield Tag.typenum(tagtype), seeker.to_s if block_given?
      end
    end
    nkdoc.to_s
  end

  # Put the content through the mill, annotate it with the parsing results, and return HTML for the whole thing
  def parse_and_annotate content
    if seeker = parse(content)
      [ :ingline ].each do |token|
        puts "-------------- #{token} ---------------"
        seekers = seeker.find(token)
        seekers.each { |seeker|
          puts seeker.head_stream.to_s
        }
      end
      seeker.enclose_all
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
      err_msg = "Illegal attempt to parse #{@entity.class.to_s} object"
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
    @parser = Parser.new content, @lexaur || Lexaur.from_tags, @entity.site.grammar_mods.clone
    @seeker = parser.match :rp_recipelist
  end

  def parse_recipe content
    @parser = Parser.new content, @lexaur || Lexaur.from_tags, @entity.site.grammar_mods.clone
    @seeker = parser.match :rp_recipe
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