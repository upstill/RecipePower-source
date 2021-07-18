require 'test_helper'

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
#   nokoscan, nkdoc, tokens, seeker: NokoScanner, Nokogiri::HTML, NokoTokens, and Seeker instances generated in parsing
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
           :trimmers, # Saved to be applied to sites and, ultimately, a parse
           :nokoscan, # A scanner for the parse
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
    @site_defaults = ParseTester.load_for_page @sample_url, @domain # Get parameters if either of these have been defined
    @grammar_mods ||= @site_defaults[:grammar_mods]
    @selector ||= @site_defaults[:selector]
    @trimmers ||= @site_defaults[:trimmers]
    @sample_url ||= @site_defaults[:sample_url]
    @sample_title ||= @site_defaults[:sample_title]
    @parse_tester = ParseTester.new grammar_mods: (@grammar_mods || {}),
                                    selector: (@selector || ''),
                                    trimmers: (@trimmers || []),
                                    ingredients: (@ingredients || []),
                                    units: (@units || []),
                                    conditions: (@conditions || []),
                                    sample_url: @sample_url,
                                    sample_title: @sample_title

    @parse_tester.save_configs @sample_url, @domain
    @page = @sample_url
    @title = @sample_title
  end
end

# This class defines a test bed for parsing in the context of site data, i.e. Finders, trimmers and content selectors
# Each instance is meant to establish parsing for pages of a specific site
class ParseTester < ActiveSupport::TestCase
  attr_reader :nokoscan, # A scanner for the parse
              :seeker, # The output of the last parse
              :parser, # The current parser, with modified grammar according to initialization parameters
              :selector, # Used by a site to select content
              :grammar_mods, # Saved to be applied to sites and, ultimately, a parse
              :trimmers, # Saved to be applied to sites and, ultimately, a parse
              :page_ref, # The PageRef generated when the parser was #apply-ed to a url
              :recipe, # The Recipe instance resulting from the parse
              :content, # The finished content resulting from the parse (should == @nkdoc.to_s)
              :lexaur # The current lexaur, which gathers tags on initialization and can be augmented by other tags
  delegate :mercury_result, :gleaning, :site, to: :page_ref
  delegate :'success?', :head_stream, :tail_stream, :find, :hard_fail?, :find_value, :find_values, :value_for, :xbounds, :token, :found_string, :found_strings, to: :seeker
  delegate :nkdoc, :tokens, to: :nokoscan
  delegate :grammar, to: :parser

  def initialize selector: '', trimmers: [], grammar_mods: {}, ingredients: [], units: [], conditions: [], sample_url: '', sample_title: ''
    super if defined?(super)
    @selector = selector
    @trimmers = trimmers
    @grammar_mods = grammar_mods
    @sample_url = sample_url
    @sample_title = sample_title
    add_tags :Ingredient, [ingredients].flatten # To support single strings
    add_tags :Unit, [units].flatten
    add_tags :Condition, [conditions].flatten
    @lexaur = Lexaur.from_tags
    # We define a useless parser to enable checks on the grammar coming out of @grammar_mods
    @parser = Parser.new 'bogus text', Lexaur.from_tags, @grammar_mods
  end

  # apply: parse either a file, a string, or an http resource, looking for the given entity (any grammar token)
  def pt_apply target = :recipe, args={}
    target, args = :recipe, target if target.is_a?(Hash)
    # filename: nil, url: nil, html: nil, tags
    filename = args.delete :filename  # Parse a local file
    url = args.delete :url # Create the target (an database object) using the url
    html = args.delete :html # Parse an html string
    @fail = args.delete :fail # Flag: expect the parse to fail
    required_tags = {}
    args.keys.each do |label|
      # Map from labels to tag type symbol for remaining arguments
      typename = label.to_s.singularize.capitalize
      typenum = Tag.typenum typename
      assert_not_equal 0, typenum, "No such thing as tags of type #{label}"
      add_tags typenum, (required_tags[typename] = [args[label]].flatten)  # Syntactic sugar: convert a single string into a singular list
    end

    @last_target = target
    # Clear all instance variables that are provided by the parse
    @nokoscan = @seeker = @page_ref = @recipe = @content = nil
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
      apply_to_string File.read(filename), token: @token, required_tags: required_tags
    when html.present?
      apply_to_string html, token: @token, required_tags: required_tags
    when url.present?
      do_recipe url, required_tags: required_tags if @token == :rp_recipe
      do_recipe_page url if @token == :rp_recipelist
    end
    @seeker&.enclose_all parser: @parser
    @seeker&.success?
  end

  # Do testing on the results of the last application.
  # This is a test of minimal results, i.e.,
  # >= 1 recipe per recipe page
  # title, ingredient list and at least two ingredients from recipe
  def assert_good token: @token, counts: {}
    default_counts = {}
    case token
    when :rp_recipe
      default_counts = {:rp_recipe => 1, :rp_title => 1 }
      nkd = Nokogiri::HTML.fragment @recipe.content
    when :rp_recipelist
      assert_equal (counts.delete(:rp_recipe) || counts.delete(:rp_title) || 1), @page_ref.recipes.to_a.count
      counts = counts.except :rp_recipe, :rp_title
      nkd = Nokogiri::HTML.fragment @recipe_page.content
    else
      default_counts = { token => 1 } # Expect one instance of the token by default
      nkd = @nokoscan.nkdoc
    end
    default_counts.merge(counts).each do |key, value|
      nfound = nkd.css(".#{key}").count
      assert_equal value, nfound, "Expected #{value} :#{key}'s, but only found #{nfound}."
    end
    nkd
  end

  # Given either a domain or a url, load an appropriate set of configs for the file
  def self.load_for_page url, domain=nil
    domain ||= PublicSuffix.parse(URI(url).host).domain if url
    if domain.present?
      # Get default values from the file indicated by domain
      filename = Rails.root.join("config", "sitedata", domain+'.yml')
      return YAML.load_file(filename) if File.exists? filename
    end
    return {}
  end

  def save_configs url, domain=nil
    domain ||= PublicSuffix.parse(URI(url).host).domain if url
    if domain.present?
      data = {
          selector: @selector,
          trimmers: @trimmers,
          grammar_mods: @grammar_mods,
          sample_url: @sample_url,
          sample_title: @sample_title
      }.compact
      filename = Rails.root.join("config", "sitedata", domain+'.yml')
      File.open(filename,"w") do |file|
        file.write data.to_yaml
      end
    end
  end

  # Augment the tags table (and the lexaur) with a collection of strings of the given type
  def add_tags tagtype, names
    return unless names.present?
    typenum = Tag.typenum(tagtype)
    names.each { |name|
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
    if finder = site.finder_for('Content')
      finder.selector = selector
    else
      site.finders.build label: 'Content', selector: selector, attribute_name: 'html'
    end
    site.trimmers = trimmers
    site.grammar_mods = grammar_mods
    site.bkg_land # Now the site should be prepared to trim recipes
  end

  def apply_to_string html, token: :rp_recipe, required_tags: {}
    @nokoscan = NokoScanner.new html
    @parser = Parser.new @nokoscan, @lexaur, @grammar_mods
    assert_not_nil @parser.grammar[token], "Can't parse for :#{token}: not found in grammar!"
    @seeker = @parser.match token
    if @fail
      refute @seeker&.success?, "Expected to but didn't fail parsing :#{token} on '#{html.truncate 200}'"
    else
      assert @seeker&.success?, "Failed to parse out :#{token} on '#{html.truncate 200}'"
      assert @seeker.tail_stream.to_s.blank?, "Stream has data remaining: '#{@seeker.tail_stream.to_s.truncate(100)}'" # Should have used up the tokens
    end
    assert_equal token, @seeker.token
    @seeker.enclose_all parser: @parser
    check_required_tags(required_tags) do |tagtype, css_class, tagset|
      missing = tagset - find_values(css_class)
      assert_empty missing, "#{tagtype}(s) declared but not found: #{missing}"
    end
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
  def do_recipe url, required_tags: {}
    @recipe = Recipe.new url: url
    @page_ref = @recipe.page_ref

    assert_includes @page_ref.recipes.to_a, @recipe # Recipe didn't build attached to its page_ref
    refute @recipe.errors.any?, "Recipe build on '#{@recipe.title}' failed:\n#{@recipe.errors.full_messages}"

    assert (@site = @recipe.site), "Recipe '#{@recipe.title}' built without site."
    prep_site @site, @selector, @trimmers, @grammar_mods
    check_attributes @site, @site.name, :name, :logo, :description

    @recipe.ensure_attributes # Perform all due diligence
    assert_equal @grammar_mods, @site.grammar_mods
    refute @recipe.errors.any?, @recipe.errors.full_messages
    assert @recipe.good? # Should have loaded and settled down
    check_attributes @recipe, @recipe.title, :title, :picurl, :description, :content

    refute @recipe.recipe_page
    assert_equal @page_ref, @recipe.page_ref
    @recipe.ensure_attributes [:content]
    refute @recipe.recipe_page # Still no @recipe page b/c it hasn't been requested
    assert_not_empty @recipe.content # ...but content from the page_ref

    @page_ref.ensure_attributes [:recipe_page]
    assert (rp = @recipe.recipe_page)
    refute rp.errors.any?, rp.errors.full_messages
    assert rp.virgin?
    @recipe.ensure_attributes [:content], overwrite: true
    # The recipe's request for content should drive the recipe_page parse
    assert_not_empty rp.content, "No content derived for recipe page"

    content = SiteServices.new(@recipe.site).trim_recipe @page_ref.content
    assert_equal content, rp.content
  end

  # Go out to the web, fetch the page at 'url', and ensure that all setup has occurred
  # url: the URL to hit
  def do_recipe_page url
    do_page_ref url, [ :recipe_page ]

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

  def do_page_ref url, attribs=[]
    @page_ref = PageRef.fetch url
    prep_site @page_ref.site, @selector, @trimmers, @grammar_mods
    assert_equal @grammar_mods, @page_ref.site.grammar_mods

    # content_needed = (attribs + @page_ref.needed_attributes).include? :content
    @page_ref.ensure_attributes attribs
    if @page_ref.content.blank? && # content_needed
      # Error: page ref couldn't extract content
      content_report = @page_ref.site.finders.to_a.keep_if { |f| f.label == 'Content' } ? '.' : ", Perhaps because the site doesn't have a Content finder?"
      @page_ref.errors.add :content, "PageRef couldn't find content" + content_report
    end
    refute @page_ref.errors.any?, @page_ref.errors.full_messages
    assert @page_ref.good? # Should have loaded and settled down
    assert_not_nil @page_ref.content
    assert_not_empty @page_ref.content
    @page_ref
  end

  def check_attributes trackable, trackable_name, *attribs
    attribs.each do |attrib|
      assert trackable.attrib_ready?(attrib), "#{trackable.class} '#{trackable_name}' couldn't extract '#{attrib}'"
    end
  end
end
