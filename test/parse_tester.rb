require 'test_helper'
require 'scraping/site_util.rb'

# A test harness for parsing functionality.
# Manages parsing of local files, strings of html, and remote pages
# Declares a #setup for a test procedure which establishes an instance of ParseTester as @parse_tester
# Provides access to instance variables of @parse_tester that pertain to either
# 1) standing elements of it, which are used in subsequent parsings
#   parser: the currently standing parser
#   lexaur: the currently standing dictionary probe
#   grammar_mods: Saved to be applied to sites and, ultimately, a parse
#   selector: ditto
#   trimmers: ditto
# 2) outcomes of the immediately prior parse, which can be examined and tested:
#   content: HTML output from the parse and markup
#   scanner, nkdoc, tokens, seeker: NokoScanner, Nokogiri::HTML, NokoTokens, and Seeker instances generated in parsing
#   recipe: the instance of Recipe that resulted from a :recipe parse
#   page_ref: its associated PageRef
#   site, gleaning, mercury_result: belong to the PageRef
module PTInterface
  attr_reader :parse_tester
  delegate :parser, # The current parser, with modified grammar according to initialization parameters
           :lexaur, # The current lexaur, which gathers tags on initialization and can be augmented by other tags
           :selector, # Used by a site to select content
           :grammar_mods, # Saved to be applied to sites and, ultimately, a parse
           :grammar, # The state of the grammar
           :patternista, :scan, :scan1, # Pattern matcher
           :trimmers, # Saved to be applied to sites and, ultimately, a parse
           :scanner, # A scanner for the parse
           :benchmark, :benchmarks,
           :nkdoc, :tokens, # The Nokogiri doc and Nokotokens
           :seeker, :token, # The output of the last parse and the resulting token
           :page_ref, # The PageRef generated when the parser was #apply-ed to a url
           :recipe, # The Recipe instance resulting from the parse
           :content, # The finished content (html) resulting from the parse (should == @nkdoc.to_s)
           :mercury_result, :gleaning, :site,
           :'success?', :head_stream, :tail_stream, :find, :hard_fail?, :find_value, :value_for, :xbounds, :found_string, :found_strings,
           :add_tags, :pt_apply, :assert_good,
           to: :parse_tester

  # Needs to be called as super from setup in parser test, with the following instance variables set (or not)
  def setup
    initters = { ingredients: @ingredients || [], units: @units || [], conditions: @conditions || [] }
    # The .yml file is derived from the test file that's being run
    # We find a 'test/sites/*.rb' file in the current stack trace
    Kernel.caller.find { |file| file.match(/test\/sites\/(.*)_test\.rb:/ ) }
    # Turn the file name into a site root
    if root = $1&.gsub('_dot_','.') # Convert file stub to site root
      # Get sample url and title, selector, trimmers and grammar mods from config file
      for_configs root, fetch_site: false do |site, data|
        initters = initters.merge data
      end
    end
    @parse_tester = ParseTester.new initters

    @page = @sample_url
    @title = @sample_title
  end
  
  def teardown
    report = ParserServices.benchmark_formatted @parse_tester.benchmarks
    report.each { |key, value| puts value}
  end
end

# This class defines a test bed for parsing in the context of site data, i.e. Finders, trimmers and content selectors
# Each instance is meant to establish parsing for pages of a specific site
class ParseTester < ActiveSupport::TestCase
  attr_reader :scanner, # A scanner for the parse
              :seeker, # The output of the last parse
              :parser, # The current parser, with modified grammar according to initialization parameters
              :selector, # Used by a site to select content
              :grammar_mods, # Saved to be applied to sites and, ultimately, a parse
              :patternista,
              :benchmark, :benchmarks,
              :trimmers, # Saved to be applied to sites and, ultimately, a parse
              :page_ref, # The PageRef generated when the parser was #apply-ed to a url
              :recipe, # The Recipe instance resulting from the parse
              :content, # The finished content resulting from the parse (should == @nkdoc.to_s)
              :lexaur # The current lexaur, which gathers tags on initialization and can be augmented by other tags
  delegate :mercury_result, :gleaning, :site, to: :page_ref
  delegate :'success?', :head_stream, :tail_stream, :find, :hard_fail?, :find_value, :find_values, :value_for, :xbounds, :token, :found_string, :found_strings, to: :seeker
  delegate :nkdoc, :tokens, to: :scanner
  delegate :grammar, :patternista, to: :parser
  delegate :scan, :scan1, to: :patternista

  def initialize params={}
    super if defined?(super)
    @selector = params[:selector]
    @trimmers = params[:trimmers]
    @grammar_mods = params[:grammar_mods]
    @sample_url = params[:sample_url]
    @sample_title = params[:sample_title]
    add_tags :Ingredient, params[:ingredients] # To support single strings
    add_tags :Unit, params[:units]
    add_tags :Condition, params[:conditions]
    Lexaur.bust_cache
    @lexaur = Lexaur.from_tags :Ingredient, :Unit, :Condition 
    Lexaur.cache_qa
    # We define a useless parser to enable checks on the grammar coming out of @grammar_mods
    @parser = Parser.new 'bogus text', @lexaur, @grammar_mods
  end

  # apply: parse either a file, a string, or an http resource, looking for the given entity (any grammar token)
  def pt_apply target = :recipe, args = {}
    target, args = :recipe, target if target.is_a?(Hash)
    # filename: nil, url: nil, html: nil, tags
    filename = args.delete :filename # Parse a local file
    url = args.delete :url # Create the target (an database object) using the url
    html = args.delete :html # Parse an html string
    string = args.delete :string # Parse a generic string
    remainder = args.delete(:remainder) || ''
    @fail = args.delete :fail # Flag: expect the parse to fail
    @expected_tokens = args.delete :expected_tokens # Specifies tokens that should be successfully found
    @expected_attributes = [args.delete(:expected_attributes)].flatten.compact # Specifies tokens that should be successfully found
    required_tags = {}
    args.keys.each do |label|
      # Map from labels to tag type symbol for remaining arguments
      typename = label.to_s.singularize.capitalize
      typenum = Tag.typenum typename
      assert_not_equal 0, typenum, "No such thing as tags of type #{label}"
      add_tags typenum, (required_tags[typename] = [args[label]].flatten) # Syntactic sugar: convert a single string into a singular list
    end

    @last_target = target
    # Clear all instance variables that are provided by the parse
    @scanner = @seeker = @page_ref = @recipe = @content = nil
    @token = case target
             when :recipe
               :rp_recipe
             when :recipe_page
               :rp_recipelist
             else
               target
             end
    case
    when filename.present?
      # Assume that the contents of a file are HTML
      apply_to_string html: File.read(filename), token: @token, required_tags: required_tags
    when html.present?
      apply_to_string html: html, token: @token, required_tags: required_tags, remainder: remainder
    when string.present?
      apply_to_string string: string, token: @token, required_tags: required_tags, remainder: remainder
    when url.present?
      do_recipe url,
                required_tags: required_tags,
                expected_attributes: @expected_attributes,
                expected_tokens: @expected_tokens if @token == :rp_recipe
      do_recipe_page url if @token == :rp_recipelist
    end
    if @seeker # Parsed html string or file directly
      # Verify the successful match on all the tokens in the @expected_tokens array
      check_content @seeker, @expected_tokens
      if html
        @seeker.enclose_all parser: @parser if html
      end
      check_content @seeker.stream, @expected_tokens
      @seeker.success?
    end
  end

  # Do testing on the results of the last application.
  # This is a test of minimal results, i.e.,
  # >= 1 recipe per recipe page
  # title, ingredient list and at least two ingredients from recipe
  def assert_good token: @token, counts: {}
    default_counts = {}
    case token
    when :rp_recipe
      default_counts = {:rp_recipe => 1, :rp_title => 1}
      nkd = Nokogiri::HTML.fragment @recipe.content
    when :rp_recipelist
      assert_equal (counts.delete(:rp_recipe) || counts.delete(:rp_title) || 1), @page_ref.recipes.to_a.count
      counts = counts.except :rp_recipe, :rp_title
      nkd = Nokogiri::HTML.fragment @recipe_page.content
    else
      default_counts = {token => 1} # Expect one instance of the token by default
      nkd = @scanner.nkdoc
    end
    default_counts.merge(counts).each do |key, value|
      nfound = nkd.css(".#{key}").count
      assert_equal value, nfound, "Expected #{value} :#{key}'s, but only found #{nfound}."
    end
    nkd
  end

  # Augment the tags table (and the lexaur) with a collection of strings of the given type
  def add_tags tagtype, names
    return unless names.present?
    typenum = Tag.typenum(tagtype)
    [names].flatten.each { |name|
      # next if Tag.strmatch(name, tagtype: typenum).present?
      tag = Tag.assert name, typenum
      if @lexaur
        @lexaur.take tag.name, tag.id
        found = nil
        scanner = StrScanner.new tag.name
        @lexaur.chunk(scanner) { |data| found ||= data }
        assert_includes found, tag.id, "Tag '#{tag.name}' is not retrievable through Lexaur"
      end
    }
  end

  private

  def prep_site site, selector, trimmers, grammar_mods = {}
    assert defined?(selector), "@selector not declared! Must be specified in #setup to get content."
    refute selector.blank?, "@selector is blank! Must be specified in #setup to get content."

    if finder = site.finder_for('Content')
      finder.selector = selector
    else
      site.finders.build label: 'Content', selector: selector, attribute_name: 'html'
    end
    site.trimmers = trimmers
    site.grammar_mods = grammar_mods
    site.bkg_land # Now the site should be prepared to trim recipes
  end

  def apply_to_string html: html, string: string, token: :rp_recipe, required_tags: {}, remainder: ''

    # One of html or string must be specified
    @scanner = html.present? ? NokoScanner.new(html) : StrScanner.new(string)
    strtrunc = (html.if_present || string).truncate 100
    ps = ParserServices.new input: @scanner,
                            token: token,
                            lexaur: @lexaur,
                            grammar_mods: @grammar_mods
    
    assert_not_nil (@parser = ps.parser), "No parser from ParserServices"
    assert_not_nil @parser.grammar[token], "Can't parse for :#{token}: not found in grammar!"

    parse_result = ps.go seeking: [token]
    assert parse_result&.success?,"Parsing Violation! Couldn't parse for :#{token} in '#{strtrunc}'" # No point proceeding if the parse fails
    assert_not_nil (@seeker = ps.parsed), "No seeker results from parsing '#{strtrunc}'"

    if Rails.env.test?
      @benchmark = ps.match_benchmarks # State of benchmarks after the last run
      @benchmarks = parser.benchmark_sum @benchmarks, @benchmark # Keep a running total across all tests
      report = ParserServices.benchmark_formatted @benchmark
      [:on, :off, :net].each { |key| puts report[key]}
    end

    missing = {}
    if @seeker
      if @fail # The parse is expected to fail
        refute @seeker&.success?, "Expected to but didn't fail parsing :#{token} on '#{strtrunc}'"
        return
      else
        assert @seeker.success?, "Failed to parse out :#{token} on '#{strtrunc}'"
        unparsed = @seeker.tail_stream.to_s.strip # Unconsumed content from the stream
        assert_equal remainder, unparsed, "Stream '#{strtrunc}' has data remaining: '#{unparsed.truncate(100)}' after parsing for :#{token}" # Should have used up the tokens
      end

      ge = @parser.grammar[token]
      assert_equal (ge[:token] if ge.is_a?(Hash)) || token, @seeker.token
      @seeker.enclose_all parser: @parser if html # Only if the parsed string was HTML
      check_required_tags(required_tags) do |tagtype, css_class, tagset|
        missing[tagtype] = tagset - find_values(css_class)
      end
      return if missing.all? &:empty? # No tags unfound
    end
=begin
    if scanned = @parser.scan.first
      # The scan may turn up the requisite element
      @seeker = scanned
      check_required_tags(required_tags) do |tagtype, css_class, tagset|
        missing[tagtype] = (missing[tagtype] || tagset) - find_values(css_class)
      end
    end
=end
    missing.each { |tagtype, missed| assert_empty missed, "#{tagtype}(s) declared but not found: #{missed}"}
  end

  # Call a block for each of the tag types in tagsets, first translating to the CSS class that encloses it
  def check_required_tags tagsets = {}
    tagsets.keys.each do |typename|
      yield typename, :"rp_#{typename.downcase}_tag", tagsets[typename]
    end
  end

  # Formerly ParseTestHelper#load_recipe
  # Go out to the web, fetch the recipe at 'url', and ensure that all setup has occurred
  # url: the URL to hit
  # required_tags: a list of tags that should be created for the recipe
  def do_recipe url, required_tags: {}, expected_tokens: [], expected_attributes: []
    #@recipe = Recipe.new url: url
    #@page_ref = @recipe.page_ref
    @recipe_page = do_recipe_page url
    @page_ref = @recipe_page.page_ref
    @recipe = @page_ref.recipes.to_a.first

    # assert_includes @page_ref.recipes.to_a, @recipe # Recipe didn't build attached to its page_ref
    # refute @recipe.errors.any?, "Recipe build on '#{@recipe.title}' failed:\n#{@recipe.errors.full_messages}"

    assert (@site = @recipe.site), "Recipe '#{@recipe.title}' built without site."
    prep_site @site, @selector, @trimmers, @grammar_mods
    check_attributes @site, @site.name, :name, :logo, :description

    @recipe.ensure_attributes # Perform all due diligence
    assert_equal @grammar_mods, @site.grammar_mods
    refute @recipe.errors.any?, @recipe.errors.full_messages
    assert @recipe.good? # Should have loaded and settled down
    check_attributes @recipe, @recipe.title, *(expected_attributes + [:title, :picurl, :description, :content])
    check_content @recipe.content, expected_tokens
    check_tags @recipe, required_tags # Confirm that tags were built

    # refute @recipe.recipe_page
    # assert_equal @page_ref, @recipe.page_ref
    # @recipe.ensure_attributes [:content]
    # refute @recipe.recipe_page # Still no @recipe page b/c it hasn't been requested
    # check_content @recipe.content, expected_tokens

    #@page_ref.ensure_attributes [:recipe_page]
    assert (rp = @recipe.recipe_page)
    #refute rp.errors.any?, rp.errors.full_messages
    #assert rp.virgin?
    #@recipe.ensure_attributes [:content], overwrite: true
    ## The recipe's request for content should drive the recipe_page parse
    #assert_not_empty rp.content, "No content derived for recipe page"

    content = SiteServices.new(@recipe.site).trim_recipe @page_ref.content
    assert_equal content, rp.content
  end

  # Go out to the web, fetch the page at 'url', and ensure that all setup has occurred
  # url: the URL to hit
  def do_recipe_page url
    do_page_ref url, [:recipe_page]

    assert (@recipe_page = @page_ref.recipe_page)
    @recipe_page.ensure_attributes [:content]
    if @recipe_page.content.blank?
      # Error: recipe_page couldn't extract content
      content_report = @recipe_page.site.finders.where(label: 'Content').exists? ? '.' : ", Perhaps because the site doesn't have a Content finder?"
      @recipe_page.errors.add :content, "PageRef couldn't find content" + content_report
    end
    refute @recipe_page.errors.any?, @recipe_page.errors.full_messages
    assert @recipe_page.good?
    assert (@page_ref.recipes.to_a.count > 0) # Need to have parsed at least one recipe out
    @recipe_page
  end

  def do_page_ref url, attribs = []
    @page_ref = PageRef.fetch url
    prep_site @page_ref.site, @selector, @trimmers, @grammar_mods
    assert_equal @grammar_mods, @page_ref.site.grammar_mods

    @page_ref.ensure_attributes attribs
    if @page_ref.content.blank?
      # Error: page ref couldn't extract content
      content_selector = @page_ref.site.finders.to_a.find { |f| f.label == 'Content' }&.selector
      content_report = content_selector.present? ? " using CSS selector '#{content_selector}'." : ", perhaps because the site doesn't have a Content selector?"
      @page_ref.errors.add :content, "not findable for PageRef" + content_report
    end
    refute @page_ref.errors.any?, @page_ref.errors.full_messages
    assert @page_ref.good? # Should have loaded and settled down
    refute_nil @page_ref.content
    refute_empty @page_ref.content
    @page_ref
  end

  def check_attributes trackable, trackable_name, *attribs
    attribs.each do |attrib|
      assert trackable.attrib_ready?(attrib), "#{trackable.class} '#{trackable_name}' couldn't extract '#{attrib}'"
    end
  end

  # Examine the content for :rp_* elements given in the expected_tokens array
  # content: either a Seeker, a String, or a Nokogiri fragment
  def check_content content, expected_tokens
    case content
    when Seeker
      [expected_tokens].flatten.each { |token| assert content.find(token).present?, "Failure! Couldn't parse out :#{token}." } if expected_tokens
      return
    when String
      assert_not_empty content, "Recipe has no parsed content"
      nkdoc = Nokogiri::HTML.fragment content
    when Nokogiri::HTML::DocumentFragment
      nkdoc = content
    end
    [expected_tokens].flatten.each { |token| assert_not_equal 0, nkdoc.css(".#{token}").count, "Can't parse out :#{token} in recipe"} if expected_tokens
  end

  # Confirm that a recipe got tagged with the named tags (currently 'Ingredient' only)
  def check_tags recipe, required_tags
    return unless ingredient_names = required_tags['Ingredient']
    # Get all ingredient tag names, whether persisted or not
    tag_names = recipe.taggings.to_a.
        map(&:tag).
        keep_if { |tag| tag.typename == 'Ingredient' }.
        map &:name
    ingredient_names.each { |expected_name| assert_includes tag_names, expected_name, "Recipe didn't get tagged with '#{expected_name}'"}
  end

end
