require 'test_helper'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

# These are tests for the default configuration of the Parser grammar
class ParserTest < ActiveSupport::TestCase

  def add_tags type, names
    return unless names.present?
    typenum = Tag.typenum(type)
    names.each { |name|
      next if Tag.strmatch(name, tagtype: typenum).present?
      tag = Tag.assert name, typenum
      @lex.take tag.name, tag.id
    }
  end

  def setup
    @amounts = [
        '1 head',
        '1 1/2 cup',
        '2 cloves',
        '1/4 cup',
        '½ cup',
        '1 small head'
    ]
    @ingred_specs = [
        '2 cloves garlic',
        '2 garlic cloves',
        'Sea salt',             # Case shouldn't matter
        '6 tablespoons butter, softened',
        '2 teaspoons Dijon mustard',
        '1/4 cup drained small capers, rinsed',
        'Grated zest of 1 lemon',
        '3 tablespoons chopped marjoram',
        'Black pepper',
        '1 pound Brussels sprouts',
        '1 small head (1/2 pound) white cauliflower',
        '1 small head (1/2 pound) Romanesco (green) cauliflower'
    ]
    @ingred_tags = %w{
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
      asparagus
      flaked\ sea\ salt
      sourdough\ bread
      garlic
      garlic\ clove
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
      Cointreau
      Romanesco\ (green)\ cauliflower}.
        each { |name| Tag.assert name, :Ingredient }
    @unit_tags = %w{ can ounce g tablespoon tbsp T. teaspoon tsp. tsp cup head pound small\ head clove cloves large }.
        each { |name| Tag.assert name, :Unit }
    @condition_tags = %w{ chopped softened rinsed crustless sifted }.
        each { |name| Tag.assert name, :Condition }
    @lex = Lexaur.from_tags
    @ings_list = <<EOF
  <p>#{@ingred_specs.join "<br>\n"}</p>
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
    (%i{ parser seeker grammar_mods entity token context_free content lexaur } - names).each do |ivname|
      assert_nil ps.instance_variable_get("@#{ivname}".to_sym), "Instance Variable #{ivname} was nil"
    end
  end

  test 'parser services management' do
    assert_raises { ParserServices.parse() }
    assert_raises { ParserServices.parse(content: 'No Intention To Parse This String') }
    ps = ParserServices.parse(content: 'Dijon mustard', token: :rp_ingstr, context_free: true)
    assert ps.success?
    check_ivs ps, :content, :nokoscan, :parser, :seeker, :context_free, :token
    ps.context_free = false
    check_ivs ps, :content, :nokoscan, :parser, :context_free, :token
    ps.entity = nil
    check_ivs ps, :content, :nokoscan, :parser, :context_free, :token# Shouldn't change any dependencies, since content is still available
    assert_raises { ps.content = nil } # Removing content without an entity for backup is an error
    ps.entity = Recipe.new
    check_ivs ps, :entity, :content, :nokoscan, :parser, :context_free, :token# Shouldn't change any dependencies, since content is still available
    ps.content = nil # Now we're allowed to clear the content
    check_ivs ps, :entity, :parser, :context_free, :token# Clearing content eliminates the scanner but not the parser
    ps.content = 'Dijon mustard'
    check_ivs ps, :entity, :content, :parser, :context_free, :token# Clearing content eliminates the scanner but not the parser
    ps.parse
    assert ps.success?
    check_ivs ps, :entity, :content, :parser, :seeker, :context_free, :token# Clearing content eliminates the scanner but not the parser
    ps.entity = nil
    check_ivs ps, :content, :parser, :context_free, :token# Clearing content eliminates the scanner but not the parser

  end

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
        :rp_ingname => { terminus: ',' }, # Test value gets added
        :rp_ing_comment => { terminus: ',' } # Make sure value gets replaced
    }
    parser = Parser.new NokoScanner.new(nonsense), grammar_mods
    assert_equal ',', parser.grammar[:rp_ingname][:terminus]
    assert_equal ',', parser.grammar[:rp_ing_comment][:terminus]
  end

  test 'parse amount specs' do
    @amounts.each do |amtstr|
      puts "Parsing '#{amtstr}'"
      nokoscan = NokoScanner.new amtstr
      is = AmountSeeker.match nokoscan, lexaur: @lex
      assert_not_nil is, "#{amtstr} doesn't parse"
      parser = Parser.new nokoscan, @lex
      seeker = parser.match :rp_amt
      assert seeker.success?
      assert_equal 2, seeker.children.count
      assert_equal :rp_amt, seeker.token
      assert_equal :rp_num_or_range, seeker.children.first.token
      assert_equal :rp_unit, seeker.children.last.token
    end
  end

  test 'parse individual ingredient' do
    ingstr = 'Dijon mustard'
    nokoscan = NokoScanner.new ingstr
    is = TagSeeker.seek nokoscan, lexaur: @lex, types: 4
    assert_not_nil is, "#{ingstr} doesn't parse"
    # ...and again using a ParserSeeker
    parser = Parser.new nokoscan, @lex
    seeker = parser.match :rp_ingname
    assert_equal 'Dijon mustard', seeker.tagdata[:name]
    assert_equal :rp_ingname, seeker.token
  end

  test 'parse alt ingredient' do
    ingstr = 'small capers, black pepper or Brussels sprouts'
    nokoscan = NokoScanner.new ingstr
    is = IngredientsSeeker.seek nokoscan, lexaur: @lex, types: 'Ingredient'
    assert_not_nil is, "#{ingstr} doesn't parse"
    assert_equal 3, is.children.count, "Didn't find 3 ingredients in #{ingstr}"
    # ...and again using a ParserSeeker
    parser = Parser.new nokoscan, @lex
    seeker = parser.match :rp_ingspec
    refute seeker.empty?
    assert_equal :rp_ingspec, seeker.token
    alts = seeker.find(:rp_ingalts)
    assert_equal 1, alts.count
    assert_equal 3, alts.first.children.count

    ingnames = alts.first.find :rp_ingname
    assert_equal 3, ingnames.count
  end

  test 'parse list of tags distributing first word' do
    lex = Lexaur.from_tags
    html = 'ground turmeric, cumin and cinnamon'
    strings = %w{ ground\ turmeric ground\ cumin ground\ cinnamon }
    parser = Parser.new html, @lex
    seeker = parser.match :rp_ingalts
    assert seeker.success?
    assert_equal :rp_ingalts, seeker.token
    assert_equal 3, seeker.find(:rp_ingname).count
    assert_equal strings, seeker.find(:rp_ingname).map(&:value)
    seeker.enclose_all parser: parser
    seeker.head_stream.nkdoc.css('.rp_ingname').each { |ingnode|
      assert_equal strings.shift, ingnode.attribute('value').to_s
    }

    html = 'ground turmeric, cumin or ground cinnamon'
    strings = %w{ ground\ turmeric ground\ cumin ground\ cinnamon }
    ps = ParserServices.new content: html, lexaur: @lex
    seeker = ps.parse token: :rp_ingline, context_free: true
    assert seeker.success?
    assert_equal :rp_ingline, seeker.token
    assert_equal 3, seeker.find(:rp_ingname).count
    assert_equal strings, seeker.find(:rp_ingname).map(&:value)
  end

  test 'parse ingredient line' do
    # Test a failed ingredient line
    html = '<strong>½ tsp. each finely grated lemon zest and juice</strong>'
    ps = ParserServices.new(content: html, lexaur: @lex)
    ps.parse token: :rp_ingline
    assert ps.hard_fail?

    html = '1/2 ounce sifted baking soda'
    ps.parse token:  :rp_ingline, content: html, context_free: true
    assert ps.success?
    assert_equal :rp_ingline, ps.token
    assert_equal 'baking soda', ps.find_value(:rp_ingname)
    assert_equal 'sifted', ps.find_value(:rp_condition)
    assert_equal 'ounce', ps.find_value(:rp_unit)
    assert_not_empty ps.find(:rp_ingspec)
    assert_not_empty ps.find(:rp_ing_comment)

    ps = ParserServices.new content: html, lexaur: @lex
    ps.parse token:  :rp_ingline, context_free: true
    assert ps.success?
    assert_equal :rp_ingline, ps.token
    assert_equal 'baking soda', ps.find_value(:rp_ingname)
    assert_equal 'sifted', ps.find_value(:rp_condition)
    assert_equal 'ounce', ps.find_value(:rp_unit)
    assert_not_empty ps.find(:rp_ingspec)
    assert_not_empty ps.find(:rp_ing_comment)

    html = '1/2 tsp. sifted (or lightly sifted) baking soda'
    ps.parse token:  :rp_ingline, content: html, context_free: true
    assert ps.success?
    assert_equal :rp_ingline, ps.token
    assert_equal 'baking soda', ps.find_value(:rp_ingname)
    assert_equal 'sifted', ps.find_value(:rp_condition)
    assert_equal 'tsp.', ps.find_value(:rp_unit)
    assert_not_empty ps.find(:rp_ingspec)
  end


  test 'parse multiple ingredient lines separated by punctuation' do
    # Try it with plain text
    html = "1 pound softened butter, 1 pound brown sugar, 1 pound white sugar, 1 tablespoon ground cinnamon and 1 teaspoon each ground clove and ground nutmeg"
    ps = ParserServices.new content: html, lexaur: @lex
    subscanners = ps.nokoscan.split(',')
    assert_equal 4, subscanners.count
    
    seeker = ps.parse token: :rp_inglist, context_free: true

    assert seeker.success?
    assert_equal 5, seeker.children.count
  end

  test 'qualified unit' do
    html = '13-ounce'
    ps = ParserServices.parse token: :rp_amt, content: html, lexaur: @lex
    assert ps.success?

    html = '(13-ounce)'
    ps = ParserServices.parse token: :rp_altamt, content: html, lexaur: @lex
    assert ps.success?

    html = '(13-ounce) can'
    ps = ParserServices.parse token: :rp_qualified_unit, content: html, lexaur: @lex
    assert ps.success?

    html = '13-ounce can'
    ps = ParserServices.parse token: :rp_qualified_unit, content: html, lexaur: @lex
    assert ps.success?

    html = '1 (13-ounce) can baking soda'
    ps = ParserServices.parse token: :rp_ingline, content: html, lexaur: @lex, context_free: true
    assert ps.success?

    html = '1 (13-ounce; 45g) can baking soda'
    ps = ParserServices.parse token: :rp_ingline, content: html, lexaur: @lex, context_free: true
    assert ps.success?

    html = '1 (13-ounce; 45g) can baking soda'
    ps = ParserServices.parse token: :rp_ingline, content: html, lexaur: @lex, context_free: true
    assert ps.success?

    html = '1 13-ounce can baking soda'
    ps = ParserServices.parse token: :rp_ingline, content: html, lexaur: @lex, context_free: true
    assert ps.success?

  end

  test 'tag has terminating period' do
    html = '1/2 tsp. sifted (or lightly sifted) baking soda'
    ps = ParserServices.parse token: :rp_ingline, content: html, lexaur: @lex, context_free: true
    assert ps.success?
    assert_equal :rp_ingline, ps.token
    assert_equal 'baking soda', ps.find_value(:rp_ingname)
    assert_equal 'sifted', ps.find_value(:rp_condition)
    assert_equal 'tsp.', ps.find_value(:rp_unit)
    assert_not_empty ps.find(:rp_ingspec)
  end

  test 'simple ingline with fractional number' do
    html = '3/4 ounce Cointreau'
    ps = ParserServices.new content: html, lexaur: @lex
    seeker = ps.parse token:  :rp_ingline, context_free: true
    assert seeker.success?
    assert_equal :rp_ingline, seeker.token
    assert_equal 'Cointreau', seeker.found_string(:rp_ingname)
    assert_equal 'ounce', seeker.found_string(:rp_unit)
    assert_equal '3/4', seeker.found_string(:rp_range)
    assert_not_empty seeker.find(:rp_ingspec)
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
    parser = Parser.new html, @lex,
                        # Here's our chance to modify the grammar
                        :rp_inglist => { :in_css_match => 'ul' },
                        :rp_ingline => { :inline => nil, :in_css_match => 'li' }

    seeker = parser.match :rp_inglist
    assert seeker.success?
    assert_equal :rp_inglist, seeker.token
    assert_equal 3, seeker.find(:rp_ingline).count

    seeker = seeker.children.first
    assert_equal :rp_ingline, seeker.token
  end

  test 'finds title in h1 tag' do
    html = "irrelevant noise <h1>Title Goes Here</h1> followed by more noise"
    parser = Parser.new html, @lex
    seeker = parser.match :rp_title
    assert_equal "Title", seeker.head_stream.token_at
    assert_equal "followed", seeker.tail_stream.token_at
  end

  test 'parse Ottolenghi ingredient list' do
    html = <<EOF
  <p><strong>30g each crustless sourdough bread</strong><br>
    <strong>½ tsp each finely grated lemon zest and juice</strong><br>
    <strong>2 anchovy fillets</strong>, drained and finely chopped<br>
    <strong>Flaked sea salt and black pepper</strong><br>
    <strong>25g unsalted butter</strong><br>
    <strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br>
    <strong>1 tbsp olive oil</strong><br>
    <strong>1 garlic clove</strong>, peeled and crushed<br>
    <strong>10g basil leaves</strong>, finely shredded
  </p>
EOF
    #   <p><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>
    html = html.gsub /\n+\s*/, ''
    # add_tags :Ingredient, %w{ sourdough\ bread pine\ nuts anchovy\ fillets sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves }
    parser = Parser.new html,
                        @lex,
                        :rp_inglist => {in_css_match: 'p'},
                        :rp_ingline => {:in_css_match => 'strong'}
    seeker = parser.match :rp_inglist
    assert seeker.success?
    lines = seeker.find(:rp_ingline)
    assert_equal 9, lines.count
    assert_equal 9, lines.keep_if { |child| child.success? }.count
  end

=begin
  test 'parse single recipe' do
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
    add_tags :Ingredient, %w{ sourdough\ bread pine\ nuts anchovy\ fillets sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves }
    parser = Parser.new html,
                        @lex,
                        :rp_title => { :in_css_match => 'h2' }, # Match everything within an <h2> tag
                        :rp_ingspec => { :in_css_match => 'strong' },
                        :rp_inglist => { :in_css_match => 'p.inglist' }
    seeker = parser.match :rp_recipe
    assert seeker.success?
    assert_equal :rp_recipe, seeker.token
    assert_equal 1, seeker.find(:rp_inglist).count
    assert_equal 9, seeker.find(:rp_inglist).first.children.keep_if(&:'success?').count

    annotated = seeker.enclose_all
    x=2
  end
=end

  test 'ingredient list with pine nuts' do
    html = '<p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>'
    add_tags :Ingredient, %w{ sourdough\ bread pine\ nuts anchovy\ fillets sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves }
    parser = Parser.new html,
                        @lex,
                        :rp_ingline => { inline: true, in_css_match: nil },
                        :rp_inglist => { in_css_match: 'p' }
    seeker = parser.match :rp_inglist
    assert seeker.success?
    ingline_seeker = seeker.find(:rp_ingline)[2]
    assert_equal '2 anchovy fillets, drained and finely chopped', ingline_seeker.to_s

    # Test that the results get enclosed properly
    seeker.enclose_all parser: parser
    assert_not_nil seeker.head_stream.nkdoc.search('.rp_inglist').first # Check that the ingredient list's <ul> is still enclosed in the original <p>
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
    # This page has several recipes, each begun with an h2 header
    parser = Parser.new html,
                        rp_recipelist: {
                            match: { at_css_match: 'h2' }
                        },
                        rp_title: { in_css_match: 'h2' }
    seeker = parser.match :rp_recipelist
    assert seeker.success?
    assert_equal :rp_recipelist, seeker.token
    assert_equal 3, seeker.children.count
    seeker.children.each { |child| assert_equal :rp_recipe, child.token }
    assert (rcp_seeker = seeker.find(:rp_recipe).first)
    assert (ttl_seeker = rcp_seeker.find(:rp_title).first)
    puts rcp_seeker.to_s
    assert_equal 'Asparagus with pine nut and sourdough crumbs (pictured above)', ttl_seeker.to_s
  end

  test 'parses multiple recipes in a page' do # From https://www.theguardian.com/lifeandstyle/2018/may/05/yotam-ottolenghi-asparagus-recipes
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
    # This page has several recipes, each begun with an h2 header
    ingreds = %w{ lemon\ zest salt sourdough\ bread pine\ nuts anchovy\ fillets flaked\ sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves
    cooking\ chorizo eggs asparagus\ spears ripe\ avocados olive\ oil lemon\ juice Greek-style\ yoghurt parsley\ leaves
    sunflower\ seeds pumpkin\ seeds maple\ syrup Salt kale white-wine\ vinegar wholegrain\ mustard asparagus frozen\ shelled\ edamame tarragon\ leaves dill
}.uniq.sort
    add_tags :Ingredient, ingreds
    parser = Parser.new html, @lex,
                        rp_recipelist: { repeating: :rp_recipe },
                        rp_recipe: { at_css_match: 'h2' },
                        rp_title: { in_css_match: 'h2' },
                        rp_inglist: { in_css_match: 'p' },
                        rp_ingline: { inline: true, in_css_match: nil }
    seeker = parser.match :rp_recipelist
    assert seeker.success?
    assert_equal :rp_recipelist, seeker.token
    assert_equal 3, seeker.children.count
    seeker.children.each { |child| assert_equal :rp_recipe, child.token }
    ingred_seekers = seeker.find :rp_ingname
    ingreds_found = ingred_seekers.map(&:to_s).map(&:downcase).uniq
    assert_empty (ingreds_found - ingreds.map(&:downcase)), "Ingredients found but not included"
    assert_equal ["lemon zest"], (ingreds.map(&:downcase) - ingreds_found), "Ingredients included but not found"

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

  def parse html, token, options={}
    add_tags :Ingredient, options[:ingredients]
    ps = ParserServices.new content: html, lexaur: @lex
    seeker = ps.parse token: :rp_ingline, context_free: (options[:context_free] == true)
    seeker.enclose_all
    [ seeker.head_stream.nkdoc, seeker ]
  end

  test 'parses ingredient list properly' do
    html = '1 ounce of bourbon, gently warmed'
    nkdoc, seeker = parse html, :rp_ingline, ingredients: %w{ bourbon Frangelico lemon\ juice }, context_free: true
    assert_equal 'bourbon', nkdoc.css('.rp_ingname').text.to_s
    assert_equal '1', nkdoc.css('.rp_num_or_range').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal ', gently warmed', nkdoc.css('.rp_ing_comment').text.to_s
    assert_equal html, nkdoc.text.to_s

    # Should have exactly the same result with content priorly enclosed in span
    html = '<li class="rp_elmt rp_ingline">1 ounce of bourbon, gently warmed</li>'
    nkdoc, seeker = parse html, :rp_ingline, context_free: true
    assert_equal '1', nkdoc.css('.rp_num_or_range').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal 'bourbon', nkdoc.css('.rp_ingname').text.to_s
    assert_equal ', gently warmed', nkdoc.css('.rp_ing_comment').text.to_s

    # Parsing a fully marked-up ingline shouldn't change it
    html = '<span class="rp_elmt rp_ingline"><span class="rp_elmt rp_amt_with_alt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit">ounce</span></span> <span class="rp_elmt rp_ingname rp_ingspec">simple syrup</span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> </span>'
    nkdoc, seeker = parse html, :rp_ingline, ingredients: %w{ simple\ syrup }, context_free: true
    assert_equal '3/4', nkdoc.css('.rp_num_or_range').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal 'simple syrup', nkdoc.css('.rp_ingname').text.to_s
    assert_equal '(equal parts sugar and hot water)', nkdoc.css('.rp_ing_comment').text.to_s

    html = '<div class="rp_elmt rp_inglist"><span class="rp_elmt rp_ingline"><span class="rp_elmt rp_amt_with_alt rp_amt"><span class="rp_elmt rp_num">3/4</span> <span class="rp_elmt rp_unit">ounce</span></span> <span class="rp_elmt rp_ingname rp_ingspec">simple syrup</span> <span class="rp_elmt rp_ing_comment">(equal parts sugar and hot water)</span> </span></div>'
    nkdoc, seeker = parse html, :rp_inglist, ingredients: %w{ bourbon Frangelico lemon\ juice }, context_free: true
    assert_equal '3/4', nkdoc.css('.rp_num_or_range').text.to_s
    assert_equal 'ounce', nkdoc.css('.rp_unit').text.to_s
    assert_equal 'simple syrup', nkdoc.css('.rp_ingname').text.to_s
    assert_equal '(equal parts sugar and hot water)', nkdoc.css('.rp_ing_comment').text.to_s
  end

end