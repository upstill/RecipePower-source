require 'recipe.rb'
require 'scraping/parser.rb'
require 'recipe_page.rb'
class ParserServices
  attr_accessor :parser, # Parser, possibly with modified grammar, to be employed
                :seeker  # Resulting tree of seeker results

  def initialize(entity: nil, content: nil, lexaur: nil, grammar_mods: nil)
    @entity = entity # Object (ie., Recipe or RecipePage) to be parsed
    @content = content
    @lexaur = lexaur
    @grammar_mods = grammar_mods
    x=2
  end

  def parser scanner=nokoscan
    @parser ||= Parser.new( scanner, @lexaur, grammar_mods)
  end

  def grammar_mods
    @grammar_mods ||= @entity&.site&.grammar_mods
  end

  def grammar_mods=gm
    if gm != @grammar_mods
      @grammar_mods = gm
      @parser = nil
    end
  end

  def content
    @content ||= @entity&.content
  end

  def content=ct
    if ct != @content
      @content = ct
      @parser = nil
      @nokoscan = nil
    end
  end

  # What is the default top-level ask for the entity?
  def token
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

  def nokoscan
    @nokoscan ||=
        case content
        when NokoScanner
          content
        when String
          NokoScanner.new content
        end
  end

  def nokoscan=nks
    if nks != @nokoscan
      @nokoscan = nks
      @parser = nil # Parser depends on the scanner
    end
  end

  def nkdoc
    nokoscan.nkdoc
  end

  def nkdoc=nkd
    if @nkdoc != nkd
      @nkdoc = nkd
      self.nokoscan = nil
    end
  end

  # Extract information from an entity (Recipe or RecipePage) or presented content
  def parse token=self.token, options={}
    self.content = options[:content] if options[:content]
    if options[:context_free]
      parser.push_grammar token => { :in_css_match => nil, :at_css_match => nil, :after_css_match => nil}
      seeker = parser.match token.to_sym
      parser.pop_grammar
    else
      seeker = parser.match token.to_sym
    end

    # For any given token, assess the result and take any needed steps to correct it.
    return seeker unless gm =
        case token
        when :rp_inglist, :rp_recipe
          # Does the list have any :ingline's? Try parsing different
          if seeker.find(:rp_ingline).empty?
            gm = { :rp_ingline => { :in_css_match => nil, :inline => true } }
          end
        end
    parser.push_grammar gm
    seeker = parser.match token.to_sym
    parser.pop_grammar
    @seeker = seeker
  end

  def annotate token, anchor_path, anchor_offset, focus_path, focus_offset
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
        seeker = parse content: elmt, token: token.to_sym
        enclose_results seeker
      end
    end
    elmt.document.to_s
  end

  def parse_and_annotate content=self.content
    if seeker = parse(content: content)
      [:rp_ingline].each do |token|
        puts "-------------- #{token} ---------------"
        seekers = seeker.find(token)
        seekers.each { |seeker|
          puts seeker
        }
      end
      enclose_results seeker
      seeker.head_stream.nkdoc.to_s
    end
  end

  def enclose_results seeker
    if seeker.success?
      seeker.enclose_all parser: parser
      seeker.head_stream.nkdoc.to_s
    end
  end

end