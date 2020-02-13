class ParsingServices
  attr_accessor :entity, # Object (ie., Recipe or RecipePage) to be parsed
                :parser, # Parser, possibly with modified grammar, to be employed
                :seeker  # Resulting tree of seeker results

  def initialize entity=nil
    @entity = entity
  end

  # annotate: apply a parsing token to the given html, using the XML paths denoting the selection
  def annotate html, token, anchor_path, anchor_offset, focus_path, focus_offset
    nkdoc = Nokogiri::HTML.fragment html
    nokoscan = NokoScanner.new nkdoc
    # Do QA on the parameters
    if anchor_path.present? && focus_path.present? && anchor_offset.to_i && focus_offset.to_i
      nokoscan.tokens.enclose_by_selection anchor_path, anchor_offset.to_i, focus_path, focus_offset.to_i, token
      nkdoc.to_s
    end
  end

  # Extract information from an entity (Recipe or RecipePage)
  def parse content
    case @entity
    when Recipe
      parse_recipe content
    when RecipePage
      parse_recipe_page content
    else
      err_msg = "Illegal attempt to parse #{@entity.class.to_s} object"
      errors.add :url, err_msg
      raise err_msg
    end
  end

  def parse_recipe_page content
    # TODO: This is a grammar for guardian.co.uk. It should be a function of sites in general
    @parser = Parser.new(content, Lexaur.from_tags)  do |grammar|
      # We start by seeking to the next h2 (title) tag
      grammar[:rp_recipelist][:start] = { match: //, within_css_match: 'h2' }
      grammar[:rp_title][:within_css_match] = 'h2' # Match all tokens within an <h2> tag
      # Stop seeking ingredients at the next h2 tag
      grammar[:rp_inglist][:bound] = { match: //, within_css_match: 'h2'}
    end
    @seeker = parser.match :rp_recipelist
  end

  def parse_recipe content
    # TODO: This is a grammar for guardian.co.uk. It should be a function of sites in general
    @parser = Parser.new(content, Lexaur.from_tags)  do |grammar|
      # We start by seeking to the next h2 (title) tag
      grammar[:rp_title][:within_css_match] = 'h2' # Match all tokens within an <h2> tag
      # Stop seeking ingredients at the next h2 tag
      grammar[:rp_inglist][:bound] = { match: //, within_css_match: 'h2'}
    end
    @seeker = parser.match :rp_recipe
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
    glean_tokens(tokens).each do |token|  # For each specified token
      @seeker.find(token).each do |seeker| # For each result under that token
        with_seeker(seeker) do |parser| # Call the given block with a parser using that seeker
          block.call parser, token
        end
      end
    end
  end

  def has? token
    @seeker.find(token).present?
  end

  def value_for token
    @seeker.find(token).first&.to_s
  end

  # Provide a path and offset in the Nokogiri doc for the results of the parse
  def xbounds
    [ @seeker.head_stream.xpath, @seeker.tail_stream.xpath(true) ]
  end

private

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