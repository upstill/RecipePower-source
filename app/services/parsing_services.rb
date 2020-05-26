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
        token = token.to_sym
        enclose_results @parser.match(token)
      end
    end
    nkdoc.to_s
  end

  def self.enclose_results seeker
    if seeker.success? && !seeker.tail_stream.more? # Parsed the WHOLE entry
      seeker.enclose_all
      nkdoc = seeker.head_stream.nkdoc
      nodes = if nkdoc.parent && nkdoc.matches?('.rp_inglist')
        [nkdoc]
      else
        nkdoc.css('.rp_inglist').to_a
      end
      # Remove all <br> tags inside the ingredient list
      nodes.each do |listnode|
        listnode.traverse do |node|
          if node.name == 'br' ||
              (node.name == 'p' && node.children.empty?) ||
              (node.matches?('.rp_ingline') && node.children.empty?)
            node.remove
          elsif node.name == 'strong' ||
              (node.matches?('.rp_ingline') && node.children.all? { |child| child.text? && child.blank? })
            node.replace node.children
          end
        end
      end
      nkdoc.to_s
    end
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
      ParsingServices.enclose_results seeker
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
    @parser = Parser.new content, @lexaur, @entity.site.grammar_mods.clone
    @seeker = parser.match :rp_recipelist
  end

  def parse_recipe content
    @parser = Parser.new content, @lexaur, @entity.site.grammar_mods.clone
    @seeker = @parser.match :rp_recipe
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