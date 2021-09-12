require 'test_helper'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'
require 'parse_tester'

# These are tests for the default configuration of the Parser grammar
class ParserTest < ActiveSupport::TestCase
  include PTInterface

  def setup
    @ingredients = %w{
      all-purpose\ flour
      eggplants
      lemon
      ground\ turmeric
      ground\ cumin
      ground\ cinnamon
      ground\ clove
      ground\ nutmeg
      brown\ sugar
      white\ sugar
      lemon\ zest
      lemon\ juice
      anchovy\ fillets
      agave\ nectar
      asparagus
      flaked\ sea\ salt
      sourdough\ bread
      garlic
      garlic\ clove
      ginger
      honey
      basil\ leaves
      salt
      baking\ soda
      sugar
      sea\ salt
      butter
      unsalted\ butter
      Dijon\ mustard
      capers
      small\ capers
      olive\ oil
      marjoram
      black\ pepper
      Brussels\ sprouts
      white\ cauliflower
      cauliflower
      sesame\ tahini
      sesame\ seeds
      Cointreau
      za'atar
      instant\ dry\ yeast
      active\ dry\ yeast
      Romanesco\ cauliflower
      water
      yellow\ onions
      lime
}
    @units = %w{ servings pounds ounces milliliters can inch knob massive\ head ounce g grams ml kg tablespoon tablespoons tbsp T. teaspoon teaspoons tsp. tsp cup cups head pound small small\ head clove cloves large oz }
    @conditions = %w{ chopped softened rinsed crustless sifted toasted grated finely\ grated lukewarm drained }
    super # Set up @parse_tester using @ingredients, @units and @conditions

    # Individual ingredient lines and what their children should be
    @ingred_lines = [
        '1 pound 5 ounces (600g) eggplants (1–2 large)', [:rp_ingspec, :rp_ing_comment],
        'Grated zest of 1 lemon', [:rp_condition_tag, :rp_ingspec, :rp_ing_comment],
        '2 cloves garlic', [:rp_ingspec, :rp_ing_comment],
        '2 garlic cloves',  [:rp_ingspec, :rp_ing_comment],
        'Sea salt',  [:rp_ingspec, :rp_ing_comment],# Case shouldn't matter
        '6 tablespoons butter, softened', [:rp_ingspec, :rp_ing_comment],
        '2 teaspoons Dijon mustard', [:rp_ingspec, :rp_ing_comment],
        '1/4 cup drained small capers, rinsed', [:rp_ingspec, :rp_ing_comment],
        '3 tablespoons chopped marjoram', [:rp_ingspec, :rp_ing_comment],
        'Black pepper', [:rp_ingspec, :rp_ing_comment],
        'Juice of ½ a lime', [:rp_ingspec, :rp_ing_comment],
        '1 pound Brussels sprouts', [:rp_ingspec, :rp_ing_comment],
        '1 small head (1/2 pound) white cauliflower', [:rp_ingspec, :rp_ing_comment],
        '1 small head (1/2 pound) Romanesco (green) cauliflower', [:rp_ingspec, :rp_ing_comment]
    ]
    @ings_list = <<EOF
  <p>#{@ingred_lines.each_slice(2).map(&:first).join "<br>\n"}</p>
EOF
    @recipe = <<EOF
<div class="entry-content"> 
  <p><b>Cauliflower and Brussels Sprouts Salad with Mustard-Caper Butter</b><br>
     Adapted from Deborah Madison, via <a href="http://www.latimes.com/features/food/la-fo-cauliflowerrec1jan10,1,2176865.story?coll=la-headlines-food">The Los Angeles Times, 1/10/07</a></p>
   
  <p>Servings: 8 (Deb: Wha?)</p>
   
#{@ings_list}
   
  <p>1. To make the mustard-caper butter, pound the garlic with a half-teaspoon salt in a mortar until smooth. Stir the garlic into the butter with the mustard, capers, lemon zest and marjoram. Season to taste with pepper. (The butter can be made a day ahead and refrigerated. Bring to room temperature before serving.)</p>
   
  <p>2. Trim the base off the Brussels sprouts, then slice them in half or, if large, into quarters. Cut the cauliflower into bite-sized pieces.</p>
   
  <p>3. Bring a large pot of water to a boil and add salt. Add the Brussels sprouts and cook for 3 minutes. Then add the other vegetables and continue to cook until tender, about 5 minutes. Drain, shake off any excess water, then toss with the mustard-caper butter. Taste for salt, season with pepper and toss again.</p>
   </div>
EOF
  end

  # Check that all of the named instance variables are set, and others are nil
  def check_ivs ps, *names
    names.each do |ivname|
      assert_not_nil ps.instance_variable_get("@#{ivname}".to_sym), "Instance Variable #{ivname} expected to be set but wasn't"
    end
    (%i{ parser seeker grammar_mods entity token content lexaur } - names).each do |ivname|
      assert_nil ps.instance_variable_get("@#{ivname}".to_sym), "Instance Variable #{ivname} was nil"
    end
  end

  # Test a succession of strings for parsing against an entry in the grammar
  # -- token: the key for the grammar entry
  # -- pairs: a series, each pair consisting of a string to test, and a list of tokens for the children of the resulting seeker
  def tst_grammar_entry token, *pairs
    while str = pairs.shift do
      pattern = pairs.shift
      puts "Parsing '#{str}'"
      pt_apply token, html: str
      assert_equal token, seeker.token, "failed to find #{token} parsing '#{str}' for #{token}"
      assert_equal pattern, seeker.children.collect(&:token), "pattern failure on parsing '#{str}' for :#{token}"
    end
  end

  test 'grammar tester' do
    nokoscan = NokoScanner.new 'a b c'
    # Should throw an error
    assert_raises { Parser.new nokoscan,
                               @lex,
                               :rp_inglist => {in_css_match: 'li', at_css_match: 'ul', },
                               :rp_title => {in_css_match: nil, at_css_match: 'ul'} }
  end

  test 'predefined ingredient lines' do
    tst_grammar_entry :rp_ingline, *@ingred_lines
  end

=begin
  test 'parser services management' do
    assert_raises { ParserServices.parse() }
    assert_raises { ParserServices.parse(content: 'No Intention To Parse This String') }
    ps = ParserServices.new(input: 'Dijon mustard', token: :rp_ingredient_tag)
    ps.parse
    assert ps.success?
    check_ivs ps, :input, :nokoscan, :parser, :token
    ps.entity = nil
    check_ivs ps, :input, :nokoscan, :parser, :token# Shouldn't change any dependencies, since content is still available
    assert_raises { ps.content = nil } # Removing content without an entity for backup is an error
    ps.entity = Recipe.new
    check_ivs ps, :entity, :content, :nokoscan, :parser, :token# Shouldn't change any dependencies, since content is still available
    ps.content = nil # Now we're allowed to clear the content
    check_ivs ps, :entity, :parser, :token# Clearing content eliminates the scanner but not the parser
    ps.content = 'Dijon mustard'
    check_ivs ps, :entity, :content, :parser, :token# Clearing content eliminates the scanner but not the parser
    ps.parse
    assert ps.success?
    check_ivs ps, :entity, :content, :parser, :seeker, :token# Clearing content eliminates the scanner but not the parser
    ps.entity = nil
    check_ivs ps, :content, :parser, :token# Clearing content eliminates the scanner but not the parser

  end
=end

  test 'grammar mods' do
    nonsense = 'No Intention To Parse This String'

    # Check that the grammar doesn't get changed gratuitously
    grammar = Parser.new(nonsense, @lex, { :rp_bogus1 => :rp_bogus2 }).grammar.except(:rp_bogus1)
    assert_equal Array, grammar[:rp_amt][:match].class

                                             # Check for grammar violations
    assert_raises { Parser.new(NokoScanner.new(nonsense), { :rp_recipelist => { :inline => true, :atline => true}}) }
    assert_raises { Parser.new(NokoScanner.new(nonsense), { :rp_recipelist => { :bound => true, :terminus => true}}) }
    assert_raises { Parser.new(NokoScanner.new(nonsense), { :rp_recipelist => { at_css_match: true, after_css_match: true}}) }

    grammar_mods = {
        :rp_ingredient_tag => { terminus: ',' }, # Test value gets added
        :rp_ing_comment => { terminus: ',' } # Make sure value gets replaced
    }
    parser = Parser.new NokoScanner.new(nonsense), grammar_mods
    assert_equal ',', parser.grammar[:rp_ingredient_tag][:terminus]
    assert_equal ',', parser.grammar[:rp_ing_comment][:terminus]
  end

  test 'parse numbers and ranges' do
    num_cases = [ '1 ¾', '6', '1/2', '9.2', '1-1/2' ]
    num_cases.each { |num|
      tst_grammar_entry :rp_num, num, [ ]
      tst_grammar_entry :rp_num_or_range, num, [ :rp_num ]
    }

    range_cases = [ '1-3', '1 to 3', '1 to 1-1/2', '1-1/2 to 2', '4-5', '4 -5', '4- 5' ]
    range_cases.each { |range| tst_grammar_entry :rp_num_or_range, range, [ :rp_range ] }
  end

  test 'unqualified amts' do
    tst_grammar_entry( :rp_unqualified_amt,
                        '1.25kg', [ :rp_amt ],
                        '25kg', [ :rp_amt ],
                        '¾kg', [ :rp_amt ],
                        '1.25 kg', [ :rp_num_or_range, :rp_unit_tag ],
                        )
  end

  test 'alt amts' do
    tst_grammar_entry( :rp_altamt,
                       '(2 3/4-pound; 1.25kg)', [ :rp_summed_amt, :rp_summed_amt ],
    )
  end

  test 'unit qualifiers' do
    tst_grammar_entry(:rp_unit_qualifier,
                       'large (15-oz)', [ :rp_size, :rp_altamt ],
                       'small', [ :rp_size ],
                       'large', [ :rp_size ],
                       'massive', [ :rp_size ],
                       )
  end

  test 'qualified units' do
    tst_grammar_entry(:rp_qualified_unit,
                       '2 inch knob', [:rp_unit_qualifier, :rp_unit],
                       'large (15-oz) can', [:rp_unit_qualifier, :rp_unit],
                       'massive (2 3/4-pound; 1.25kg) head', [:rp_unit_qualifier, :rp_unit],
                       '15-oz can', [:rp_unit_qualifier, :rp_unit],
                       'small head', [:rp_unit_qualifier, :rp_unit],
    )

  end

  test 'parse amounts' do
    tst_grammar_entry(:rp_amt,
                       '1 pound 5 ounces', [:rp_summed_amt],
                       '1 massive (2 3/4-pound; 1.25kg) head', [:rp_num, :rp_qualified_unit],
                       '1 large (15-oz) can', [:rp_qualified_unit],
                       '2 tablespoons (30ml)', [:rp_num, :rp_unit],
                       "3/4 ounce (about 1/4 cup; 20g)", [:rp_num, :rp_unit],
                       '1 teaspoon (5ml)', [:rp_num, :rp_unit],
                       '13-ounce', [:rp_num, :rp_unit],
                       '1 (13-ounce) can', [:rp_num, :rp_qualified_unit],
                       '2 inch knob', [ :rp_qualified_unit ],
                       '1 1/2 cup', [:rp_num, :rp_unit],
                       '1 large (15-oz) can', [:rp_qualified_unit],
                       '4 -5 servings', [:rp_range, :rp_unit],
                       '1 head', [:rp_num, :rp_unit],
                       '2 cloves', [:rp_num, :rp_unit],
                       '1/4 cup', [:rp_num, :rp_unit],
                       '½ cup', [:rp_num, :rp_unit],
                       '1 small head', [:rp_num, :rp_qualified_unit],
                       '1 massive (2 3/4-pound; 1.25kg) head', [:rp_num, :rp_qualified_unit]
                       )
  end

  test 'parse ingspecs' do
    tst_grammar_entry( :rp_ingspec,
        '2 tablespoons (30ml) sesame tahini', [ :rp_amt, :rp_ingalts ],
        "3/4 ounce (about 1/4 cup; 20g) za'atar", [ :rp_amt, :rp_ingalts ],
        '1 teaspoon (5ml) honey or agave nectar', [ :rp_amt, :rp_ingalts ],
    )
  end

  test 'parse individual ingredient' do
    ingstr = 'Dijon mustard'
    is = TagSeeker.seek NokoScanner.new(ingstr), lexaur: lexaur, types: 4
    assert_not_nil is, "#{ingstr} doesn't parse"
    tst_grammar_entry( :rp_ingredient_tag,
                        ingstr, []
                        )
    # ...and again using a ParserSeeker
    pt_apply :rp_ingredient_tag,
             html: 'Dijon mustard',
             ingredients: 'Dijon mustard'
  end

  test 'parse alt ingredient' do
    ingstr = 'small capers, black pepper or Brussels sprouts'
    is = IngredientsSeeker.seek NokoScanner.new(ingstr), lexaur: lexaur, types: 'Ingredient'
    assert_not_nil is, "#{ingstr} doesn't parse"
    assert_equal 3, is.children.count, "Didn't find 3 ingredients in #{ingstr}"
    # ...and again using a ParserSeeker
    pt_apply :rp_ingspec, html: ingstr
    refute seeker.empty?
    assert_equal :rp_ingspec, seeker.token
    alts = seeker.find(:rp_ingalts)
    assert_equal 1, alts.count
    assert_equal 3, alts.first.children.count

    ingnames = alts.first.find :rp_ingredient_tag
    assert_equal 3, ingnames.count
  end

  test 'parse list of tags distributing first word' do
    pt_apply :rp_ingalts,
             html: 'instant or active dry yeast'

    strings = %w{ ground\ turmeric ground\ cumin ground\ cinnamon }
    pt_apply :rp_ingalts,
             html: 'ground turmeric, cumin or cinnamon',
             ingredients: strings

    assert_equal :rp_ingalts, seeker.token
    assert_equal 3, seeker.find(:rp_ingredient_tag).count
    assert_equal strings.sort, seeker.find(:rp_ingredient_tag).map(&:value).sort
    seeker.head_stream.nkdoc.css('.rp_ingredient_tag').each { |ingnode|
      assert_includes strings, ingnode.attribute('value').to_s
    }

    pt_apply :rp_ingline,
             html: 'ground turmeric, cumin or ground cinnamon',
             ingredients: %w{ ground\ turmeric ground\ cumin ground\ cinnamon }
    assert seeker.success?
    assert_equal :rp_ingline, seeker.token
    assert_equal 3, seeker.find(:rp_ingredient_tag).count
    assert_equal strings.sort, seeker.find(:rp_ingredient_tag).map(&:value).sort
  end

  test 'abbreviated unit' do

    html = '<strong>½ tsp. each finely grated lemon zest and juice</strong>'
    pt_apply :rp_ingline,
             html: html,
             units: 'tsp.',
             conditions: 'finely grated',
             ingredients: %w{ lemon\ zest lemon\ juice }

  end

  test 'parse summed amounts' do
    sums = [
        '1 ¾ cups plus 2 tablespoons', [ :rp_unqualified_amt, :rp_unqualified_amt ]
    ]
    tst_grammar_entry :rp_summed_amt, *sums
    pt_apply :rp_summed_amt,
             html: sums.first,
             units: %w{ cups tablespoons }
  end

  test 'parse ingredients' do
    @ingredients.each do |ingred_name|
      tst_grammar_entry :rp_ingredient_tag, ingred_name, []
    end
  end

  test 'parse ingredient line' do

    tst_grammar_entry :rp_ingredient_tag, 'all-purpose flour', [  ]
    tst_grammar_entry :rp_ingalts, 'all-purpose flour', [ :rp_ingredient_tag ]
    pt_apply :rp_ingspec,
             html: '1 ¾ cups plus 2 tablespoons all-purpose flour',
             units: %w{ cups tablespoons },
             ingredients: %w{ all-purpose\ flour }

    pt_apply :rp_amt,
             html: '1 ¾ cups plus 2 tablespoons/240 grams',
             units: %w{ cups tablespoons grams }

    pt_apply :rp_altamt,
             html: '/240 grams',
             units: %w{ grams }

    pt_apply :rp_ingline,
             html: '1 teaspoon toasted sesame seeds',
             units: %w{ teaspoon },
             conditions: %w{ toasted },
             ingredients: 'sesame seeds'

    html = 'Salt and black pepper'
    pt_apply :rp_ingalts,
             html: html,
             ingredients: %w{ salt black\ pepper }
    pt_apply :rp_ingline,
             html: html,
             ingredients: %w{ salt black\ pepper }

    # Test a failed ingredient line
    pt_apply :rp_ingline,
             html: '<strong>½ tsp. each finely grated lemon zest and juice</strong>',
             ingredients: %w{ lemon\ zest lemon\ juice },
             conditions: %w{ finely\ grated }

    pt_apply :rp_ingline,
             html: '1/2 ounce sifted baking soda',
             ingredients: 'baking soda',
             units: 'ounce',
             conditions: 'sifted'
    assert_equal :rp_ingline, token
    assert_not_empty find(:rp_ingspec)
    assert_not_empty find(:rp_ing_comment)
    
    pt_apply :rp_ingline,
             html: '1 ¾ cups all-purpose flour',
             ingredients: %w{ all-purpose\ flour },
             units: %w{ cups }

    pt_apply :rp_ingline,
             html: '¾ cup/180 milliliters lukewarm water',
             ingredients: %w{ lukewarm\ water },
             units: %w{ milliliters }

    pt_apply :rp_summed_amt,
             html: '1 ¾ cups plus 2 tablespoons',
             units: %w{ cups tablespoons }

    pt_apply :rp_ingline,
             html: '1 ¾ cups/240 grams all-purpose flour',
             ingredients: %w{ all-purpose\ flour },
             units: %w{ cups grams }

    pt_apply :rp_ingspec,
             html: '1 ¾ cups plus 2 tablespoons/240 grams all-purpose flour',
             ingredients: %w{ all-purpose\ flour },
             units: %w{ cups tablespoons grams }

    pt_apply :rp_ingline,
             html: '1 ¾ cups plus 2 tablespoons/240 grams all-purpose flour',
             ingredients: %w{ all-purpose\ flour },
             units: %w{ cups tablespoons grams }

    pt_apply :rp_ingline,
             html: '1 ¾ cups plus 2 tablespoons/240 grams all-purpose flour',
             ingredients: %w{ all-purpose\ flour },
             units: %w{ cups tablespoons grams }

    pt_apply :rp_ingline,
             html: '¾ cup/180 milliliters lukewarm water',
             ingredients: %w{ lukewarm\ water },
             units: %w{ milliliters }

    pt_apply :rp_ingline,
             html: '4 small yellow onions (about 1 pound; 455g total), ends trimmed but root left intact, peeled, and quartered lengthwise through the root',
             ingredients: 'yellow onions',
             units: 'small'

    pt_apply :rp_summed_amt,
             html: '1 ¾ cups plus 2 tablespoons',
             units: %w{ cups tablespoons }

    pt_apply :rp_ingline,
             html: '1/2 ounce sifted baking soda',
             ingredients: 'baking soda',
             units: 'ounce',
             conditions: 'sifted'

    assert_equal :rp_ingline, token
    assert_not_empty find(:rp_ingspec)
    assert_not_empty find(:rp_ing_comment)

    pt_apply :rp_ingline,
             html: '1/2 tsp. sifted (or lightly sifted) baking soda',
             ingredients: 'baking soda'

    assert_equal :rp_ingline, token
    assert_not_empty find(:rp_ingspec)
  end

  test 'parse multiple ingredient lines separated by punctuation' do
    pt_apply :rp_inglist,
             html: "1 pound softened butter, 1 pound brown sugar, 1 pound white sugar, 1 tablespoon ground cinnamon and 1 teaspoon each ground clove and ground nutmeg"
    assert_equal 5, seeker.children.count
    subscanners = nokoscan.split(',')
    assert_equal 4, subscanners.count
  end

  # These Unit tags should be distinct and distinctly available. But the default normalize_name method
  # fails to distinguish between them.
  test 'abbreviated tags differing in punctuation' do
    Tag.where(tagtype: Tag.typenum(:Unit)).destroy_all
    units = %w{ t T t. T. tsp tsp. }
    add_tags :Unit, units
    assert_equal 6, Tag.where(tagtype: 5).count
    units.each { |unitstr|
      pt_apply :rp_unit_tag, html: unitstr, units: unitstr
      refute tail_stream.more?
    }

    pt_apply :rp_unit, html: 'tsp.', units: 'tsp.'

    # An unadorned unit should also answer to a unit, since the qualifications are optional
    pt_apply :rp_amt, html: 'tsp', units: 'tsp'

    pt_apply :rp_amt, html: '1 tsp', units: 'tsp'

    pt_apply :rp_ingline, html: '1 tsp baking soda', units: 'tsp', ingredients: 'baking soda'

    pt_apply :rp_ingline, html: '1 tsp. baking soda', units: 'tsp.', ingredients: 'baking soda'

    pt_apply :rp_ingline,
             html: '1/2 tsp. sifted (or lightly sifted) baking soda',
             ingredients: 'baking soda',
             conditions: 'sifted',
             units: 'tsp.'
    assert_not_empty find(:rp_ingspec)
  end

  test 'qualified unit' do

    pt_apply :rp_altamt, html: '(13-ounce)'

    pt_apply :rp_altamt, html: '(13-ounce; 45g)' # can baking soda'
  end

  test 'ingredient lines' do

    pt_apply :rp_ingspec, html: '2 tablespoons (30ml) sesame tahini'

    pt_apply :rp_ingline, html: '1 13-ounce can baking soda'

    pt_apply :rp_ingline, html: '2 inch knob of ginger, peeled and thinly sliced'

    pt_apply :rp_ingline, html: "3/4 ounce (about 1/4 cup; 20g) za'atar, divided"

    pt_apply :rp_ingline, html: '1 teaspoon (5ml) honey or agave nectar'

    pt_apply :rp_ingline, html: '2 can (30g) baking soda'

    pt_apply :rp_ingline, html: '1 (13-ounce) can baking soda'

    pt_apply :rp_ingline, html: '1 (13-ounce; 45g) can baking soda'

    pt_apply :rp_ingline, html: '1 (13-ounce; 45g) can baking soda'

  end

  test 'simple ingline with fractional number' do
    pt_apply :rp_ingline,
             html: '3/4 ounce Cointreau',
             ingredients: 'Cointreau',
             units: 'ounce'
    assert_equal '3/4', found_string(:rp_num)
    assert_not_empty find(:rp_ingspec)
  end

  test 'parse ing list from modified grammar' do
    html = <<EOF
<ul>
  <li>1/2 tsp. baking soda</li>
  <li>1 tsp. salt</li>
  <li>1 T. sugar</li>
</ul>
EOF
    html = html.gsub(/\n+\s*/, '')
    @parse_tester = ParseTester.new grammar_mods: { :gm_inglist => :unordered_list }
    pt_apply :rp_inglist, html: html,
             ingredients: %w{ baking\ soda salt sugar },
             units: %w{ tsp. T. }
             assert_equal 3, find(:rp_ingline).count
    assert_equal :rp_inglist, seeker.token
    assert_equal :rp_ingline, seeker.children.first.token
    assert_equal 3, seeker.find(:rp_ingline).count
  end

  test 'finds title in h1 tag' do
    html = "irrelevant noise <h1>Title Goes Here</h1> followed by more noise"
    pt_apply :rp_title, html: html
    assert_equal 'Title Goes Here', seeker.to_s
  end

  test 'various ingredient lines' do
    pt_apply :rp_amt,
             html: '<li>1 large</li>',
             units: 'large'

    pt_apply :rp_ingspec,
             html: '1 large cauliflower',
             ingredients: 'cauliflower',
             units: 'large'

    # Note: rinsed and finely grated are tags, but not ingredients
    pt_apply :rp_ingline,
             html: '<li>1 large cauliflower, rinsed and finely grated (220g net weight)</li>',
             ingredients: 'cauliflower',
             units: 'large'
  end

  test 'parse single recipe' do
    @parse_tester = ParseTester.new grammar_mods: { :gm_inglist => { flavor: :paragraph, css_class: 'inglist' } }
    html = <<EOF
<div class="content__article-body from-content-api js-article__body" itemprop="articleBody" data-test-id="article-review-body">
  <p><span class="drop-cap"><span class="drop-cap__inner">M</span></span>ost asparagus dishes are easy to prepare (this is no artichoke or broad bean) and quick to cook (longer cooking makes it go grey and lose its body). The price you pay for this instant veg, though, is that it has to be super-fresh. As Jane Grigson observed: “Asparagus needs to be eaten the day it is picked. Even asparagus by first-class post has lost its finer flavour.” Realistically, most of us don’t live by an asparagus field, so have to extend Grigson’s one-day rule. Even so, the principle is clear: for this delicate vegetable, the fresher the better.</p>
  <h2>Asparagus with pine nut and sourdough crumbs (pictured above)</h2>
  <p>Please don’t be put off by the anchovies in this, even if you don’t like them. There are only two fillets, and they add a wonderfully deep, savoury flavour; there’s nothing fishy about the end product, I promise. If you’re not convinced and would rather leave them out, increase the salt slightly. Serve with meat, fish or as part of a spring meze; or, for a summery starter, with a poached egg.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>20 min</strong><br>Serves <strong>4</strong></p>
  <p class="inglist"><strong>30g crustless sourdough bread</strong><br><strong>½ tsp each finely grated lemon zest and juice</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded</p>
  <p>Heat the oven to 220C/425F/gas 7. Blitz the sourdough in a food processor to fine crumbs, then pulse a few times with the pine nuts, anchovies, a generous pinch of flaked sea salt and plenty of pepper, until everything is finely chopped.<br></p>
</div>
EOF
    pt_apply :rp_recipe,
             html: html,
             ingredients: 'pine nuts'
    assert_equal :rp_recipe, seeker.token
    assert_equal 1, seeker.find(:rp_inglist).count
    assert_equal 10, seeker.find(:rp_inglist).first.children.keep_if(&:'success?').count

  end

  test 'ingredient list with pine nuts' do
    @parse_tester = ParseTester.new grammar_mods: { :gm_inglist => :paragraph }
    pt_apply :rp_inglist, html: '<p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>',
             :ingredients => %w{ sourdough\ bread pine\ nuts anchovy\ fillets flaked\ sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves }
    assert_equal '2 anchovy fillets, drained and finely chopped', seeker.find(:rp_ingline)[2].to_s
  end

  test 'identifies multiple recipes in a page' do # From https://www.theguardian.com/lifeandstyle/2018/may/05/yotam-ottolenghi-asparagus-recipes
    html = <<EOF
<div class="content__article-body from-content-api js-article__body" itemprop="articleBody" data-test-id="article-review-body">
  <p><span class="drop-cap"><span class="drop-cap__inner">M</span></span>ost asparagus dishes are easy to prepare (this is no artichoke or broad bean) and quick to cook (longer cooking makes it go grey and lose its body). The price you pay for this instant veg, though, is that it has to be super-fresh. As Jane Grigson observed: “Asparagus needs to be eaten the day it is picked. Even asparagus by first-class post has lost its finer flavour.” Realistically, most of us don’t live by an asparagus field, so have to extend Grigson’s one-day rule. Even so, the principle is clear: for this delicate vegetable, the fresher the better.</p>
  <h2>Asparagus with pine nut and sourdough crumbs (pictured above)</h2>
  <p>Please don’t be put off by the anchovies in this, even if you don’t like them. There are only two fillets, and they add a wonderfully deep, savoury flavour; there’s nothing fishy about the end product, I promise. If you’re not convinced and would rather leave them out, increase the salt slightly. Serve with meat, fish or as part of a spring meze; or, for a summery starter, with a poached egg.</p>
  <p>Prep <strong>5 min</strong><br>Cook: <strong>20 min</strong><br>Serves <strong>4</strong></p>
  <p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>
  <p>Heat the oven to 220C/425F/gas 7. Blitz the sourdough in a food processor to fine crumbs, then pulse a few times with the pine nuts, anchovies, a generous pinch of flaked sea salt and plenty of pepper, until everything is finely chopped.<br></p>
  <h2>Soft-boiled egg with avocado, chorizo and asparagus</h2>

  <p>Play around with this egg-in-a-cup dish, depending on what you have around: sliced cherry tomatoes are a good addition, for example, as is grated cheese or a drizzle of truffle oil. Omit the chorizo, if you like, to make it vegetarian. Serve with toasted bread.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>15 min</strong><br>Serves <strong>4</strong></p>
  <p><strong>70g cooking chorizo</strong>, skinned and broken into 2cm chunks<br><strong>4 large eggs</strong>, at room temperature<br><strong>8 asparagus spears,</strong> woody ends trimmed and cut into 6cm-long pieces<br><strong>2 ripe avocados</strong>, stoned and flesh scooped out<br><strong>1 tbsp olive oil</strong><br><strong>2 tsp lemon juice</strong><br><strong>Flaked sea salt and black pepper</strong><br><strong>80g Greek-style yoghurt</strong><br><strong>5g parsley leaves</strong>, finely chopped</p>
  <h2>Kale and grilled asparagus salad</h2>

  <p>There’s a little bit of massaging and marinating involved here, but you can do that well ahead of time, if need be. Just don’t mix everything together until the last minute.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>35 min</strong><br>Serves <strong>4-6</strong></p>
  <p><strong>30g sunflower seeds</strong><br><strong>30g pumpkin seeds</strong><br><strong>1½ tsp maple syrup</strong><br><strong>Salt and black pepper</strong><br><strong>250g kale</strong>, stems discarded, leaves torn into roughly 4-5cm pieces<br><strong>3 tbsp olive oil</strong><br><strong>1½ tbsp white-wine vinegar</strong><br><strong>2 tsp wholegrain mustard</strong><br><strong>500g asparagus</strong>, woody ends trimmed<br><strong>120g frozen shelled edamame</strong>, defrosted<br><strong>10g tarragon leaves</strong>, roughly chopped<br><strong>5g dill</strong>, roughly chopped</p>
  <p>To serve, toss the edamame and herbs into the kale, then spread out on a large platter. Top with the asparagus and candied seeds, and serve at once.</p>

</div>
EOF
    @parse_tester = ParseTester.new :grammar_mods => {
        :gm_inglist => :paragraph,
        rp_recipelist: {
            match: {at_css_match: 'h2'}
        },
        rp_title: {in_css_match: 'h2'}
    }
    pt_apply :rp_recipelist, html: html
    assert_equal 3, seeker.children.count
    seeker.children.each { |child| assert_equal :rp_recipe, child.token }
    assert (rcp_seeker = seeker.find(:rp_recipe).first)
    assert (ttl_seeker = rcp_seeker.find(:rp_title).first)
    assert_equal 'Asparagus with pine nut and sourdough crumbs (pictured above)', ttl_seeker.to_s
  end

  test 'parses multiple recipes in a page' do
    # From https://www.theguardian.com/lifeandstyle/2018/may/05/yotam-ottolenghi-asparagus-recipes
    # This page has several recipes, each begun with an h2 header
    ingreds = %w{ lemon\ zest salt sourdough\ bread pine\ nuts anchovy\ fillets flaked\ sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves
    cooking\ chorizo eggs asparagus\ spears ripe\ avocados olive\ oil lemon\ juice Greek-style\ yoghurt parsley\ leaves
    sunflower\ seeds pumpkin\ seeds maple\ syrup kale white-wine\ vinegar wholegrain\ mustard asparagus frozen\ shelled\ edamame tarragon\ leaves dill
}.uniq.sort

    line = "<strong>asparagus</strong>, woody ends trimmed<strong>"
    add_tags  :Ingredient, ingreds
    pt_apply :rp_ingalts, html: line, ingredients: 'asparagus'

    line = "<strong>asparagus</strong>, woody ends trimmed<strong>"
    pt_apply :rp_ingspec, html: line, ingredients: [ 'asparagus' ]

    line = "<strong>400g asparagus</strong>, woody ends trimmed<strong>"
    pt_apply :rp_ingline, html: line, ingredients: [ 'asparagus' ]

    list = "<p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>"
    @parse_tester = ParseTester.new ingredients: ingreds,
                                    grammar_mods: {
                                        :gm_inglist => :paragraph,
                                        rp_recipelist: {repeating: :rp_recipe},
                                        rp_recipe: {at_css_match: 'h2'},
                                        rp_title: {in_css_match: 'h2'},
                                    }
    pt_apply :rp_inglist, html: list

    html = <<EOF
<div class="content__article-body from-content-api js-article__body" itemprop="articleBody" data-test-id="article-review-body">
  <p><span class="drop-cap"><span class="drop-cap__inner">M</span></span>ost asparagus dishes are easy to prepare (this is no artichoke or broad bean) and quick to cook (longer cooking makes it go grey and lose its body). The price you pay for this instant veg, though, is that it has to be super-fresh. As Jane Grigson observed: “Asparagus needs to be eaten the day it is picked. Even asparagus by first-class post has lost its finer flavour.” Realistically, most of us don’t live by an asparagus field, so have to extend Grigson’s one-day rule. Even so, the principle is clear: for this delicate vegetable, the fresher the better.</p>
  <h2>Asparagus with pine nut and sourdough crumbs (pictured above)</h2>
  <p>Please don’t be put off by the anchovies in this, even if you don’t like them. There are only two fillets, and they add a wonderfully deep, savoury flavour; there’s nothing fishy about the end product, I promise. If you’re not convinced and would rather leave them out, increase the salt slightly. Serve with meat, fish or as part of a spring meze; or, for a summery starter, with a poached egg.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>20 min</strong><br>Serves <strong>4</strong></p>
  <p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>
  <p>Heat the oven to 220C/425F/gas 7. Blitz the sourdough in a food processor to fine crumbs, then pulse a few times with the pine nuts, anchovies, a generous pinch of flaked sea salt and plenty of pepper, until everything is finely chopped.<br></p>
  <h2>Kale and grilled asparagus salad</h2>

  <p>There’s a little bit of massaging and marinating involved here, but you can do that well ahead of time, if need be. Just don’t mix everything together until the last minute.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>35 min</strong><br>Serves <strong>4-6</strong></p>
  <p><strong>30g sunflower seeds</strong><br><strong>30g pumpkin seeds</strong><br><strong>1½ tsp maple syrup</strong><br><strong>Salt and black pepper</strong><br><strong>250g kale</strong>, stems discarded, leaves torn into roughly 4-5cm pieces<br><strong>3 tbsp olive oil</strong><br><strong>1½ tbsp white-wine vinegar</strong><br><strong>2 tsp wholegrain mustard</strong><br><strong>500g asparagus</strong>, woody ends trimmed<br><strong>120g frozen shelled edamame</strong>, defrosted<br><strong>10g tarragon leaves</strong>, roughly chopped<br><strong>5g dill</strong>, roughly chopped</p>
  <p>To serve, toss the edamame and herbs into the kale, then spread out on a large platter. Top with the asparagus and candied seeds, and serve at once.</p>

  <h2>Soft-boiled egg with avocado, chorizo and asparagus</h2>

  <p>Play around with this egg-in-a-cup dish, depending on what you have around: sliced cherry tomatoes are a good addition, for example, as is grated cheese or a drizzle of truffle oil. Omit the chorizo, if you like, to make it vegetarian. Serve with toasted bread.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>15 min</strong><br>Serves <strong>4</strong></p>
  <p><strong>70g cooking chorizo</strong>, skinned and broken into 2cm chunks<br><strong>4 large eggs</strong>, at room temperature<br><strong>8 asparagus spears,</strong> woody ends trimmed and cut into 6cm-long pieces<br><strong>2 ripe avocados</strong>, stoned and flesh scooped out<br><strong>1 tbsp olive oil</strong><br><strong>2 tsp lemon juice</strong><br><strong>flaked sea salt and black pepper</strong><br><strong>80g Greek-style yoghurt</strong><br><strong>5g parsley leaves</strong>, finely chopped</p>
</div>
EOF
    pt_apply :rp_recipelist, html: html
    assert_equal :rp_recipelist, seeker.token
    assert_equal 3, seeker.children.count
    seeker.children.each { |child| assert_equal :rp_recipe, child.token }
    ingred_seekers = seeker.find :rp_ingredient_tag
    ingreds_found = ingred_seekers.map(&:value).uniq
    assert_empty (ingreds_found - ingreds), "Ingredients found but not included"
    assert_empty (ingreds - ingreds_found), "Ingredients included but not found"

    assert (rcp_seeker = seeker.find(:rp_recipe).first)
    assert (ttl_seeker = rcp_seeker.find(:rp_title).first)
    puts rcp_seeker.to_s
    assert_equal 'Asparagus with pine nut and sourdough crumbs (pictured above)', ttl_seeker.to_s
    assert (prep_seeker = parser.seek :rp_prep_time)
    assert_equal 'Prep 5 min', prep_seeker.to_s
    assert (cook_seeker = parser.seek :rp_cook_time)
    assert_equal 'Cook 20 min', cook_seeker.to_s
    assert (servings_seeker = parser.seek :rp_serves)
    assert_equal "Serves 4", servings_seeker.to_s
  end

  test 'parses ingredient list properly' do
    html = '1 ounce of bourbon, gently warmed'
    pt_apply :rp_ingline, html: html, ingredients: %w{ bourbon }, units: %w{ ounce }
    assert_equal 'bourbon', nkdoc.css('.rp_ingredient_tag').text.to_s
    assert_equal '1', nkdoc.css('.rp_num').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal ', gently warmed', nkdoc.css('.rp_ing_comment').text.to_s
    assert_equal html, nkdoc.text.to_s

    # Should have exactly the same result with content priorly enclosed in span
    html = '<li class="rp_elmt rp_ingline">1 ounce of bourbon, gently warmed</li>'
    pt_apply :rp_ingline, html: html
    assert_equal '1', nkdoc.css('.rp_num').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal 'bourbon', nkdoc.css('.rp_ingredient_tag').text.to_s
    assert_equal ', gently warmed', nkdoc.css('.rp_ing_comment').text.to_s

    # Parsing a fully marked-up ingline shouldn't change it
    html = '<span class="rp_elmt rp_ingline"><span class="rp_elmt rp_amt_with_alt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit">ounce</span></span> <span class="rp_elmt rp_ingredient_tag rp_ingspec">simple syrup</span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> </span>'
    pt_apply :rp_ingline, html: html, ingredients: %w{ simple\ syrup }
    assert_equal '3/4', nkdoc.css('.rp_num').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal 'simple syrup', nkdoc.css('.rp_ingredient_tag').text.to_s
    # assert_equal '(equal parts sugar and hot water)', nkdoc.css('.rp_ing_comment').text.to_s

    html = '<div class="rp_elmt rp_inglist"><span class="rp_elmt rp_ingline"><span class="rp_elmt rp_amt_with_alt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit">ounce</span></span> <span class="rp_elmt rp_ingredient_tag rp_ingspec">simple syrup</span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> </span></div>'
    pt_apply :rp_inglist, html: html
    assert_equal '3/4', nkdoc.css('.rp_num').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal 'simple syrup', nkdoc.css('.rp_ingredient_tag').text.to_s
    # assert_equal '(equal parts sugar and hot water)', nkdoc.css('.rp_ing_comment').text.to_s
  end

  def assert_invariance input_html, output_nkdoc
    # input = Nokogiri::XML(html,&:noblanks)
    input = pretty_indented_html input_html
    # output = Nokogiri::XML(nkdoc.to_s,&:noblanks)
    output = pretty_indented_html output_nkdoc.to_s
    puts "<<< Input:", input, ">>> Output:", output
    assert_equal input, output, "Nokogiri result differs from input\n<<<< Before:\n#{input}\n<<< After:\n#{output}\n"
  end

  test "marked-up html remains invariant after parsing and tagging" do

    # Parsing a fully marked-up ingline shouldn't change it
    html = <<EOF
<li class="rp_elmt rp_ingline">
  <span class="rp_elmt rp_ingspec"><span class="rp_elmt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit rp_unit_tag" value="ounce">ounce</span></span> <span class="rp_elmt rp_ingalts rp_ingredient_tag" value="simple syrup">simple syrup</span></span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span>
</li>
EOF
    pt_apply :rp_ingline, html: html, ingredients: 'simple syrup', units: 'ounce'
    assert_invariance html, nkdoc

    html = <<EOF
<ul class="rp_elmt rp_inglist">
  <li class="rp_elmt rp_ingline">
    <span class="rp_elmt rp_ingspec">
      <span class="rp_elmt rp_amt_with_alt rp_amt">
        <span class="rp_elmt rp_num">3/4</span> 
        <span class="rp_elmt rp_unit rp_unit_tag">ounce</span>
      </span> 
      <span class="rp_elmt rp_ingredient_tag rp_ingalts">simple syrup</span> 
    </span> 
    <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> 
  </li>
</ul>
EOF
    pt_apply :rp_inglist, html: html, ingredients: 'simple syrup', units: 'ounce'
    assert_invariance html, nkdoc

    html = <<EOF
<ul class="rp_elmt rp_inglist">
  <li class="rp_elmt rp_ingline"><span class="rp_elmt rp_ingspec">
    <span class="rp_elmt rp_amt_with_alt rp_amt">
      <span class="rp_elmt rp_num">3/4</span> 
      <span class="rp_elmt rp_unit_tag rp_unit">ounce</span>
    </span>
    <span class="rp_elmt rp_ingalts rp_ingredient_tag" value="simple syrup">simple syrup</span>
    <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> 
  </span></li>
</ul>
EOF
    pt_apply :rp_inglist, html: html, ingredients: 'simple syrup', units: 'ounce'
    assert_invariance html, nkdoc

    html = <<EOF
    <span class="rp_elmt rp_amt">
      <span class="rp_elmt rp_num">3/4</span> 
      <span class="rp_elmt rp_unit_tag rp_unit">ounce</span>
    </span>
EOF
    pt_apply :rp_amt, html: html, units: 'ounce'
    assert_invariance html, nkdoc

    html = <<EOF
<ul class="rp_elmt rp_inglist">
  <li class="rp_elmt rp_ingline"><span class="rp_elmt rp_ingspec">
    <span class="rp_elmt rp_amt_with_alt rp_amt">
      <span class="rp_elmt rp_num">3/4</span> 
      <span class="rp_elmt rp_unit_tag rp_unit">ounce</span>
    </span>
      <span class="rp_elmt rp_ingalts rp_ingredient_tag" value="simple syrup">simple syrup</span>
  </span></li>
</ul>
EOF
    pt_apply :rp_inglist, html: html, ingredients: 'simple syrup', units: 'ounce'
    assert_invariance html, nkdoc

    html = <<EOF
<ul class="rp_elmt rp_inglist">
  <li class="rp_elmt rp_ingline">a dash of Angostura.</li>
</ul>
EOF
    pt_apply :rp_inglist, html: html, ingredients: 'Angostura', units: 'dash'
    html = nkdoc.to_s
    pt_apply :rp_inglist, html: html, ingredients: 'Angostura', units: 'dash'
    assert_invariance html, nkdoc

    html = <<EOF
<ul class="rp_elmt rp_inglist">
  <li class="rp_elmt rp_ingline">3/4 ounce simple syrup (equal parts sugar and hot water)</li>
  <li class="rp_elmt rp_ingline">a dash of Angostura</li>
</ul>
EOF

    @parse_tester = ParseTester.new grammar_mods: { :gm_inglist => :unordered_list }
    pt_apply :rp_inglist, html: html, ingredients: %w{ simple\ syrup Angostura }, units: %w{ ounce dash }
    html = nkdoc.to_s
    pt_apply :rp_inglist, html: html, ingredients: 'Angostura', units: 'dash'
    assert_invariance html, nkdoc
  end

  test 'recipe with predeclared ingredient list' do
    @parse_tester = ParseTester.new grammar_mods: { :rp_inglist => {:in_css_match => 'div.rp_inglist'} }
    pt_apply :rp_recipe,
             html: '<div class="rp_elmt rp_recipe"> <h3><strong>Intermediate: Frangelico Sour</strong></h3> <p>Like its cousin the Amaretto Sour.</p> <p><em>Instructions: </em>In a cocktail shaker <em>without </em>ice, combine </p> <div class="rp_elmt rp_inglist">1 ounce of bourbon, 1 ounce of Frangelico, 3/4 ounce lemon juice, <span class="rp_elmt rp_ingline"><span class="rp_elmt rp_amt_with_alt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit">ounce</span></span> <span class="rp_elmt rp_ingredient_tag rp_ingspec">simple syrup</span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> </span>and a dash of Angostura.</div> </div>',
             ingredients: %w{ bourbon Frangelico lemon\ juice simple\ syrup Angostura },
             units: 'dash'

    assert_equal 5, seeker.find(:rp_ingline).count
  end

  test 'comma-separated ingredient list' do
    html = '<p>1 ounce of bourbon, 1 ounce of Frangelico, 3/4 ounce lemon juice, <span class="rp_elmt rp_ingline"><span class="rp_elmt rp_amt_with_alt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit">ounce</span></span> <span class="rp_elmt rp_ingredient_tag rp_ingspec">simple syrup</span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> </span>and a dash of Angostura.</p>'
    @parse_tester = ParseTester.new grammar_mods: { :gm_inglist => :inline }
    pt_apply :rp_inglist,
             html: html,
             ingredients: %w{ bourbon Frangelico lemon\ juice simple\ syrup Angostura },
             units: 'dash'
    assert_equal 5, seeker.find(:rp_ingline).count
  end

  test 'proper handling of embedded parentheticals' do
    html = "(or up to four hours, if you want to get ahead).\nWarm"
    pt_apply :rp_amt,
             html: html,
             fail: true
  end

end
