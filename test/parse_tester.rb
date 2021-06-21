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
# 2) artifacts of the immediate prior parse, which can be examined and tested:
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
           :trimmers, # Saved to be applied to sites and, ultimately, a parse
           :nokoscan, # A scanner for the parse
           :nkdoc, :tokens, # The Nokogiri doc and Nokotokens
           :seeker, :token, # The output of the last parse and the resulting token
           :page_ref, # The PageRef generated when the parser was #apply-ed to a url
           :recipe, # The Recipe instance resulting from the parse
           :content, # The finished content (html) resulting from the parse (should == @nkdoc.to_s)
           :mercury_result, :gleaning, :site,
           :'success?', :find, :hard_fail?, :find_value, :value_for, :xbounds, :found_string, :found_strings,
           :pt_apply,
           to: :parse_tester

  # Needs to be called as super from setup in parser test, with the following instance variables set (or not)
  def setup
    @parse_tester = ParseTester.new
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
  delegate :'success?', :find, :hard_fail?, :find_value, :value_for, :xbounds, :token, :found_string, :found_strings, to: :seeker
  delegate :nkdoc, :tokens, to: :nokoscan

  def initialize selector: '', trimmers: [], grammar_mods: {}, ingredients: [], units: [], conditions: []
    super if defined?(super)
    @selector = selector
    @trimmers = trimmers
    @grammar_mods = grammar_mods
    add_tags :Ingredient, ingredients
    add_tags :Unit, units
    add_tags :Condition, conditions
    @lexaur = Lexaur.from_tags
  end

  # apply: parse either a file, a string, or an http resource, looking for the given entity (any grammar token)
  def pt_apply target = :recipe, filename: nil, url: nil, html: nil, ingredients: [], units: [], conditions: []
    @last_target = target
    # Clear all instance variables that are provided by the parse
    @nokoscan = @seeker = @page_ref = @recipe = @content = nil
    add_tags :Ingredient, ingredients
    add_tags :Unit, units
    add_tags :Condition, conditions
    # add_tags :Dish,[ 'noodles and pasta' ]
    # add_tags :Untyped, [ 'pan-fried noodles' ]
    token = case target
            when :recipe
              :rp_recipe
            when :recipe_page
              :rp_recipelist
            else
              target
            end
=begin
    return (apply_to_string File.read(filename), token: token) if filename.present?
    return (apply_to_string html, token: token) if html.present?
    return (apply_to_url url, target: target) if url.present?
=end
    case
    when filename.present?
      apply_to_string File.read(filename), token: token
    when html.present?
      apply_to_string html, token: token
    when url.present?
      apply_to_url url, target: target
    end
    assert_empty ingredients-found_strings(:rp_ingredient_tag)
    assert_empty units-found_strings(:rp_unit_tag)
    assert_empty conditions-found_strings(:rp_conditions_tag)
    @seeker&.enclose_all parser: @parser
    @seeker&.success?
  end

  # Do testing on the results of the last application
  def assert_good

  end

  private

  # Augment the tags table (and the lexaur) with a collection of strings of the given type
  def add_tags typesym, names
    return unless names.present?
    typenum = Tag.typenum(typesym)
    names.each { |name|
      # next if Tag.strmatch(name, tagtype: typenum).present?
      tag = Tag.assert name, typenum
      if @lexaur
        @lexaur.take tag.name, tag.id
        found = nil
        scanner = StrScanner.new tag.name
        @lexaur.chunk(scanner) { |data| found = data }
        assert_includes found, tag.id, "Tag '#{tag.name}' is not retrievable through Lexaur"
      end
    }
  end

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

  def apply_to_string html, token: :rp_recipe
    @nokoscan = NokoScanner.new html
    @parser = Parser.new @nokoscan, @lexaur, @grammar_mods
    if @seeker = @parser.match(token)
      @seeker.enclose_all parser: @parser
    end
    assert @seeker&.success?
  end

  # Formerly ParseTestHelper#load_recipe
  # Go out to the web, fetch the recipe at 'url', and ensure that all setup has occurred
  # url: the URL to hit
  def apply_to_url url, target: :recipe
    @recipe = Recipe.new url: url
    @page_ref = @recipe.page_ref
    assert_includes @page_ref.recipes.to_a, @recipe # Recipe didn't build attached to its page_ref
    prep_site @recipe.site, @selector, @trimmers, @grammar_mods
    @recipe.ensure_attributes # Perform all due diligence
    assert_equal @grammar_mods, @recipe.site.grammar_mods
    refute @recipe.errors.any?, @recipe.errors.full_messages
    assert @recipe.good? # Should have loaded and settled down

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

    content = SiteServices.new(@recipe.site).trim_recipe @page_ref.content
    assert_equal content, rp.content
  end


end
