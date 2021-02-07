require 'recipe.rb'
require 'scraping/parser.rb'
require 'recipe_page.rb'
class ParserServices
  attr_reader :seeker,  # Resulting tree of seeker results (returned by #parse)
              # :parser, # Parser, possibly with modified grammar, to be employed
              :grammar_mods, # Modifications to be used on the parser beforehand
              # :token, # What the last parse requested
              :context_free # Whether the last parse was context free
  delegate :'success?', :find, :hard_fail?, :find_value, to: :seeker

  def initialize(entity: nil, token: nil, content: nil, lexaur: nil, grammar_mods: nil)
    self.entity = entity # Object (ie., Recipe or RecipePage) to be parsed
    self.token = token
    self.content = content
    self.lexaur = lexaur
    self.grammar_mods = grammar_mods
  end

=begin
Here is where all dependencies in the parser are expressed: dependent variables are cleared
when the entities on which they depend are expressed.
The dependencies are as follows:
@seeker
  @token
  @context_free
  @grammar_mods
  @nokoscan
    @content
      @entity
  @parser
    @lexaur
...therefore, when any of them are set, their dependents must be nulled out (recursively)
=end

  # Apply the parser to a NokoScanner
  def parser ct=@content
    self.content = ct
    @parser ||= Parser.new( nokoscan, @lexaur, @entity&.site&.grammar_mods)
  end

  def parser=p # There's no reason for anything but nil to be set
    if p != @parser
      @parser = p
      @seeker = nil
    end
  end

  def lexaur=l
    if l != @lexaur
      @lexaur = l
      self.parser = nil
    end
  end

  def grammar_mods=gm
    if gm != @grammar_mods
      @grammar_mods = gm
      @seeker = nil
    end
  end

  # Setting @content invalidates @nokoscan--unless it IS a NokoScanner
  def content=ct
    if ct != @content
      if ct.nil? && @entity.nil?
        raise "Error in ParserServices#content=: can't clear content without an entity"
      end
      @content = ct
      self.nokoscan = ct.is_a?(NokoScanner) ? ct : nil
    end
  end

  def entity=e
    if @entity != e
      @entity = e
      # Changing the entity changes grammar mods
      self.seeker = nil
      self.nokoscan = nil if @content.nil?
    end
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
    if tk != @token
      @token = tk
      self.seeker = nil
    end
  end

  def context_free=b
    if @context_free != b
      @context_free = b
      self.seeker = nil
    end
  end

  def seeker=s
    if s != @seeker
      @seeker = s
    end
  end

  # The NokoScanner is derived from the designated content or, if no content, the entity
  # per NokoScanner initialization, @content may be any of a string, scanner, tokens or Nokogiri document
  def nokoscan
    @nokoscan ||=
        case @content
        when NokoScanner
          @content
        when nil # Fall back on the entity's content
          NokoScanner.new @entity&.content
        else # Let NokoScanner sort it out
          NokoScanner.new @content
        end
  end

  def nokoscan=nks
    if nks != @nokoscan
      @nokoscan = nks
      self.seeker = nil # Parser depends on the scanner
    end
  end

  def nkdoc
    @nkdoc ||= nokoscan.nkdoc
  end

  def nkdoc=nkd
    if @nkdoc != nkd
      @nkdoc = nkd
      self.content = nkd
    end
  end

  def ParserServices.parse entity: nil, content: nil, token: nil, lexaur: nil, context_free: nil, grammar_mods: nil
    # There must be EITHER content or an entity specified
    if content.nil? && entity.nil?
      raise "Error in ParserServices.parse: must provide EITHER content or an entity"
    end
    # Likewise, either a token or an entity must be specified
    if token.nil? && entity.nil?
      raise "Error in ParserServices.parse: must provide EITHER a token or an entity"
    end
    ps = ParserServices.new entity: entity, token: token, content: content, lexaur: lexaur, grammar_mods: grammar_mods
    ps.parse context_free: context_free
    ps
  end

  # Extract information from an entity (Recipe or RecipePage) or presented content
  def parse options={}
    self.content = options[:content] if options[:content]
    self.context_free = options[:context_free] if options[:context_free]
    self.token = options[:token] if options[:token]
    parser.stream = nokoscan
    if @context_free
      parser.push_grammar token => { :in_css_match => nil, :at_css_match => nil, :after_css_match => nil}
      @seeker = parser.match token
      parser.pop_grammar
    else
      @seeker = parser.match token
    end

    # For any given token, assess the result and take any needed steps to correct it.
    return @seeker unless gm =
        case token
        when :rp_inglist, :rp_recipe
          # Does the list have any :ingline's? Try parsing different
          if @seeker.find(:rp_ingline).empty?
            gm = { :rp_ingline => { :in_css_match => nil, :inline => true } }
          end
        end
    parser.push_grammar gm
    @seeker = parser.match token.to_sym
    parser.pop_grammar
    @seeker
  end

  # Put the content through the mill, annotate it with the parsing results, and return HTML for the whole thing
  def annotate
    if seeker&.success?
      seeker.enclose_all parser: parser
      nkdoc.to_s
    end
  end

  def annotate_selection token, anchor_path, anchor_offset, focus_path, focus_offset
    # nokoscan = NokoScanner.new content
    # nkdoc = nokoscan.nkdoc
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
    if (class_attr = elmt.attribute('class')) &&
        (token = class_attr.to_s.split.find { |cl| cl.match(/^rp_/) && cl != 'rp_elmt' }) &&
        token.present?
      # For direct Tag terminals, short-circuit the parsing process with a tag lookup
      if tagtype = Parser.tagtype(token) # This token calls for a tag
        # Go directly to tag lookup in the database
        typenum = Tag.typenum tagtype
        tagstr = elmt.to_s
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
        parse content: elmt, token: token.to_sym
        seeker.enclose_all parser: parser
      end
    end
    elmt.document.to_s
  end

  private

end