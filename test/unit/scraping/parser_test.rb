require 'test_helper'
require 'scraping/scanner.rb'
require 'scraping/lexaur.rb'
require 'scraping/parser.rb'

class ParserTest < ActiveSupport::TestCase

  def add_tags type, names
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
      Romanesco\ (green)\ cauliflower}.
        each { |name| Tag.assert name, :Ingredient }
    @unit_tags = %w{ g tablespoon tbsp T. teaspoon tsp. tsp cup head pound small\ head clove }.
        each { |name| Tag.assert name, :Unit }
    @condition_tags = %w{ chopped softened rinsed crustless }.
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

  test 'parse amount specs' do
    @amounts.each do |amtstr|
      puts "Parsing '#{amtstr}'"
      nokoscan = NokoScanner.from_string amtstr
      is = AmountSeeker.match nokoscan, lexaur: @lex
      assert_not_nil is, "#{amtstr} doesn't parse"
      parser = Parser.new nokoscan, @lex
      seeker = parser.match :rp_amt
      assert seeker
      assert_equal 2, seeker.children.count
      assert_equal :rp_amt, seeker.token
      assert_equal :rp_num, seeker.children.first.token
      assert_equal :rp_unit, seeker.children.last.token
    end
  end

  test 'parse individual ingredient' do
    ingstr = 'Dijon mustard'
    nokoscan = NokoScanner.from_string ingstr
    is = TagSeeker.seek nokoscan, lexaur: @lex, types: 4
    assert_not_nil is, "#{ingstr} doesn't parse"
    # ...and again using a ParserSeeker
    parser = Parser.new nokoscan, @lex
    seeker = parser.match :rp_ingname
    assert_equal 1, seeker.tag_ids.count
    assert_equal :rp_ingname, seeker.token
  end

  test 'parse alt ingredient' do
    ingstr = 'small capers, black pepper or Brussels sprouts'
    nokoscan = NokoScanner.from_string ingstr
    is = IngredientsSeeker.seek nokoscan, lexaur: @lex, types: 'Ingredient'
    assert_not_nil is, "#{ingstr} doesn't parse"
    assert_equal 3, is.tag_seekers.count, "Didn't find 3 ingredients in #{ingstr}"
    # ...and again using a ParserSeeker
    parser = Parser.new nokoscan, @lex
    seeker = parser.match :rp_ingspec
    refute seeker.empty?
    assert_equal 1, seeker.children.count
    assert_equal :rp_ingspec, seeker.token

    seeker = seeker.children.first
    refute seeker.empty?
    assert_equal 3, seeker.children.count
    assert_equal :rp_ingalts, seeker.token

    seeker = seeker.children.first
    refute seeker.empty?
    assert_equal 0, seeker.children.count
    assert_equal :rp_ingname, seeker.token
  end

=begin
  test 'parse individual ingredient specs' do
    @ingred_specs.each do |ingspec|
      puts "Parsing '#{ingspec}'"
      nokoscan = NokoScanner.from_string ingspec
      is = IngredientSpecSeeker.match nokoscan, lexaur: @lex
      assert_not_nil is, "#{ingspec} doesn't parse"
    end
  end

  test 'parse a whole ingredient list' do
    nokoscan = NokoScanner.from_string @ings_list
  end

  test 'find the ingredient list embedded in a recipe' do
    nokoscan = NokoScanner.from_string @recipe
    il = IngredientListSeeker nokoscan
    assert_not_nil il
  end
=end

  test 'parse ing list from modified grammar' do
    html = <<EOF
<ul>
  <li>1/2 tsp. baking soda</li>
  <li>1 tsp. salt</li>
  <li>1 T. sugar</li>
</ul>
EOF
    html = html.gsub(/\n+\s*/, '')
    parser = Parser.new(html, @lex) do |grammar|
      # Here's our chance to modify the grammar
      grammar[:rp_inglist][:match] = { repeating: :rp_ingline, :within_css_match => 'li' }
      grammar[:rp_inglist][:within_css_match] = 'ul'
    end
    seeker = parser.match :rp_inglist
    assert_not_nil seeker
    assert_equal :rp_inglist, seeker.token
    assert_equal 3, seeker.children.count

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
    <strong>2 anchovy fillets</strong>, drained and finely chopped<br>
    <strong>Flaked sea salt and black pepper</strong><br>
    <strong>25g unsalted butter</strong><br>
    <strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br>
    <strong>1 tbsp olive oil</strong><br>
    <strong>1 garlic clove</strong>, peeled and crushed<br>
    <strong>10g basil leaves</strong>, finely shredded<br>
    <strong>½ tsp each finely grated lemon zest and juice</strong>
  </p>
EOF
    #   <p><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>
    html = html.gsub /\n+\s*/, ''
    parser = Parser.new(html, @lex) do |grammar|
      #grammar[:rp_ingline][:match]  = [
      #:rp_ingname,
      #    { optional: :rp_ing_comment } # Anything can come between the ingredient and the end of line
      #]
    end
    seeker = parser.match :rp_inglist
    assert seeker
  end

  test 'parse single recipe' do
    html = <<EOF
<div class="content__article-body from-content-api js-article__body" itemprop="articleBody" data-test-id="article-review-body">
  <p><span class="drop-cap"><span class="drop-cap__inner">M</span></span>ost asparagus dishes are easy to prepare (this is no artichoke or broad bean) and quick to cook (longer cooking makes it go grey and lose its body). The price you pay for this instant veg, though, is that it has to be super-fresh. As Jane Grigson observed: “Asparagus needs to be eaten the day it is picked. Even asparagus by first-class post has lost its finer flavour.” Realistically, most of us don’t live by an asparagus field, so have to extend Grigson’s one-day rule. Even so, the principle is clear: for this delicate vegetable, the fresher the better.</p>
  <h2>Asparagus with pine nut and sourdough crumbs (pictured above)</h2>
  <p>Please don’t be put off by the anchovies in this, even if you don’t like them. There are only two fillets, and they add a wonderfully deep, savoury flavour; there’s nothing fishy about the end product, I promise. If you’re not convinced and would rather leave them out, increase the salt slightly. Serve with meat, fish or as part of a spring meze; or, for a summery starter, with a poached egg.</p>
  <p>Prep <strong>5 min</strong><br>Cook <strong>20 min</strong><br>Serves <strong>4</strong></p>
  <p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>
  <p>Heat the oven to 220C/425F/gas 7. Blitz the sourdough in a food processor to fine crumbs, then pulse a few times with the pine nuts, anchovies, a generous pinch of flaked sea salt and plenty of pepper, until everything is finely chopped.<br></p>
</div>
EOF
    parser = Parser.new(html, @lex)  do |grammar|
      grammar[:rp_title][:within_css_match] = 'h2' # Match all tokens within an <h2> tag
    end
    seeker = parser.match :rp_recipe
    assert seeker
    assert_equal :rp_recipe, seeker.token
    assert_equal 11, (seeker.children.first.tail_stream.pos - seeker.children.first.head_stream.pos)
    assert_equal :rp_inglist, seeker.children[1].token
    assert_equal 8, seeker.children[1].children.count
  end

  test 'ingredient list with pine nuts' do
    html = '<p><strong>30g crustless sourdough bread</strong><br><strong>30g pine nuts</strong><br><strong>2 anchovy fillets</strong>, drained and finely chopped<br><strong>Flaked sea salt and black pepper</strong><br><strong>25g unsalted butter</strong><br><strong>400g asparagus</strong>, woody ends trimmed<strong> </strong><br><strong>1 tbsp olive oil</strong><br><strong>1 garlic clove</strong>, peeled and crushed<br><strong>10g basil leaves</strong>, finely shredded<br><strong>½ tsp each finely grated lemon zest and juice</strong></p>'
    add_tags :Ingredient, %w{ sourdough\ bread pine\ nuts anchovy\ fillets sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves }
    parser = Parser.new(html, @lex)
    seeker = parser.match :rp_inglist
    assert seeker
    ingline_seeker = seeker.find(:rp_ingline)[2]
    assert_equal '2 anchovy fillets, drained and finely chopped', ingline_seeker.to_s
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
    ingreds = %w{ sourdough\ bread pine\ nuts anchovy\ fillets sea\ salt black\ pepper unsalted\ butter asparagus olive\ oil garlic\ clove basil\ leaves }
    add_tags :Ingredient, ingreds
    parser = Parser.new(html, @lex)  do |grammar|
      # We start by seeking to the next h2 (title) tag
      grammar[:rp_recipelist][:start] = { match: //, within_css_match: 'h2' }
      grammar[:rp_title][:within_css_match] = 'h2' # Match all tokens within an <h2> tag
      # Stop seeking ingredients at the next h2 tag
      grammar[:rp_inglist][:bound] = { match: //, within_css_match: 'h2' }
    end
    seeker = parser.match :rp_recipelist
    assert seeker
    assert_equal :rp_recipelist, seeker.token
    assert_equal 4, seeker.children.count
    seeker.children.each { |child| assert_equal :rp_recipe, child.token }
    assert (rcp_seeker = seeker.find(:rp_recipe).first)
    assert (ttl_seeker = rcp_seeker.find(:rp_title).first)
    puts rcp_seeker.to_s
    assert_equal 'Asparagus with pine nut and sourdough crumbs (pictured above)', ttl_seeker.to_s
    assert (prep_seeker = parser.seek :rp_prep_time)
    assert_equal 'Prep 5 min', prep_seeker.to_s
    assert (cook_seeker = parser.seek :rp_cook_time)
    assert_equal 'Cook: 20 min', cook_seeker.to_s
    assert (servings_seeker = parser.seek :rp_serves)
    assert_equal 'Serves 4', servings_seeker.to_s
    ingred_seekers = rcp_seeker.find :rp_ingname
    ingreds_found = ingred_seekers.map &:to_s
    assert_equal ingreds, ingreds_found
  end

end