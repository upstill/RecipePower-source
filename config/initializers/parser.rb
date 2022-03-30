require 'scraping/parser.rb'
# This is the DSL for parsing a recipe. The parsing engine, however, doesn't really concern recipes per se. It only
# takes a grammar and a token generator and, if successful, creates an abstract syntax tree that just denotes what range of
# tokens went into each match. In the case of a NokoScanner token generator, that syntax tree can be used to modify the
# corresponding Nokogiri tree to mark each successful range of tokens with its element.
#
# The syntax tree is a hash, where the keys are elements of the language (a 'token'), and the value is a 'specification',
# describing how to match that entity
# The keys are symbols. THEY WILL ALSO BE USED TO IDENTIFY THE MATCH IN THE NOKOGIRI TREE
#   by enclosing the found content in a <div class="rp_elmt #{token}">
# Specifications can be of several types:
# -- A String is matched literally
# -- A Symbol is either a token with another entry in the grammar, or a special token with algorithmic meaning in
#   the engine. None of the latter are currently defined, so all symbols must have entries in the grammar
#   NB: The use of a symbol as specification at the top level (ie., token1: token2 ) would
#   be redundant (unless token2 is a special token), since it does nothing but declare an alias
# -- A Class is a subclass of Seeker that takes responsibility for producing a match and returning itself if found.
#   (see the "abstract" class declaration of Seeker for details)
# -- A RegExp is consulted for a match in text
# -- An Array gives a sequence of specifications to match. This is the basis of recursion.
# -- A Hash is a set of symbol/value pairs specifying instructions and constraints on what matches
#     Generally speaking, a hash will include a :match key labeling a further specification, and other options for processing
#     the set. Alternatively, a :tag or multiple :tags may be specified
#    match: denotes the token or tokens to match. For matching an array, this option is redundant if nothing else is
#       being specified, i.e. token: { match: [a, b, c] } is no different from token: [a, b, c]. It's only
#       needed if other elements of the hash (key/value pairs) are needed to assert constraints.
#    tag: means to match a Tag from the dictionary, with the tag type or types given as the value. (Any of the type
#       specifiers supported by the Tag class--integer, symbol or name--can be used as the type or element of the array)
#       NB: matching a tag can consume more than one string token in the stream
#    regexp: specifies a string that will be converted to a regular expression and applied to the next token.
#       NB: this is redundant with respect to { match: /regexp/ } but lends itself to persistence
#    seeker: specifies a subclass of Seeker (or a string naming that class) that will handle matching. Options to the
#       seeker may be passed in an accompanying options: hash
#       Also redundant wrt { match: Class } but works for persistence
#
#   By default, the members of an array are to be matched, in order, with material intervening between them
#       ignored. Further flags below modify this behavior when set to 'true'. For convenience/syntactic sugar, any of
#       these flags may be used in place of 'match'
#    checklist: the array of items may be found in any order. The set matches when all its items (exc. optional ones) match
#    repeating: stipulates that the set should be matched repeatedly; effectively a wildcard marker
#    or: matches when ANY among the set matches (tried in order)
#
# Other options apply to both singular and collective matches:
#    list: expects a series of matches on the given specification, interspersed with ',' and
#       terminated with 'and' or 'or'. If the option is set to a string, that's used as the terminator
#    optional: stipulates that the match is optional.
#       For convenience/syntactic sugar, { optional: :token } is equivalent to { match: :token, optional: true }
#    bound: gives a match that terminates the process, for example an EOL token. The given match is NOT consumed: the
#       stream reverts to the beginning of the matched bound. This is useful,
#       for example, to terminate processing at the end of a line, while leaving the EOL token for subsequent processing
#    in_css_match: the search is constrained to the contents of the first node matching the associated CSS selector
#    at_css_match: the search advances to the first node matching the associated CSS selector
#    after_css_match: the search starts immediately after the first node matching the associated CSS selector
#        NB: the three css matchers may appear in context with the :repeating flag; in that case, the search proceeds
#         in parallel on all matching nodes. (multiple matches from :at_css_match do not overlap: after the first,
#         each one foreshortens the previous one)
#       Notice that once a page is parsed and tokens marked in the DOM, there is an implicit :on_css_match to the stipulated
#       token ("div.rp_elmt.#{token}"). Of course, when first parsing an undifferentiated document, no such markers
#       are found. But they eventually get there when the seeker encloses found content.
#    :inline, :atline: constrains the match to the beginning of a line, as defined by
#       either the next newline character, or beginning of <p> or <li> tags, or after <br> tag--whichever comes first.
#       :inline also foreshortens the stream at the next line so defined.
Parser.init_grammar(
    rp_recipelist: {
        # Matching the title anchors each recipe; nil includes all subsequent content.
        # The distribution mechanism will clip that subsequent content to the next match.
        # Thus, we get a list of recipes, each of which begins with a title and includes
        # all content until the next one, labelled with :rp_recipe
        distribute: [:rp_title, nil],
        under: :rp_recipe
    },
    rp_recipe: {
        match: [
            :rp_title, # {optional: :rp_title},
            # Everything after the ingredient list
            {checklist: [
                { distribute: [ { optional: :rp_inglist_header }, :rp_inglist, :rp_instructions ],
                  under: :rp_recipe_section },
                {optional: :rp_author},
                {optional: :rp_prep_time},
                {optional: :rp_cook_time},
                {optional: :rp_total_time},
                {optional: :rp_serves},
                {optional: :rp_yields}
            ]},
        ]
    },
    # Hopefully sites will specify how to find the title in the extracted text
    rp_title: {
        in_css_match: 'h1,h2,h3'
    }, # Match all tokens within a header tag (by default)
    rp_author: {
        match: [ { :trigger => /^Author:?$/ }, nil ],
        in_css_match: nil,
        atline: true
    },
    rp_prep_time: {
        match: [ { :trigger => /^Prep:?$/i }, { match: /^time:?$/i, optional: true }, :rp_time ],
        in_css_match: nil,
        atline: true
    },
    rp_cook_time: {
        match: [ { :trigger => /^(Cook|Active):?$/i }, { match: /^time:?$/i, optional: true }, :rp_time ],
        in_css_match: nil,
        atline: true
    },
    rp_total_time: {
        match: [ { :trigger => /^Total:?$/i }, { match: /^time:?$/i, optional: true }, :rp_time ],
        in_css_match: nil,
        atline: true
    },
    rp_time: [ :rp_num, /^(mins?\.?|minutes?)?$/ ],
    rp_yields: {
        match: [ { :trigger => /^(Servings|Makes|Yield):$/i }, :rp_num_or_range, :rp_unit ], # :rp_amt ],
        in_css_match: nil,
        atline: true
    },
    rp_serves: {
        or: [
            #[ /^Serv(ing|e)s?:$/i, :rp_num_or_range ],
            #[ :rp_num_or_range, /^Servings?$/i ],
            [ { :trigger => /^Serv(ing|e)s?:?$/i }, :rp_num_or_range ],
            [ { :trigger => /^\d+$/, match: :rp_num_or_range }, /^Servings?$/i ],
        ],
        in_css_match: nil,
        atline: true
    },
    :rp_instructions => nil,
    :rp_recipe_section => {
        :distribute => [ :rp_inglist, :rp_instructions ]
    },
    :rp_inglist_header => {
        :in_css_match => 'h4.wprm-recipe-ingredient-group-name'
    },
    rp_inglist: {
                  # match: [ { or: [:rp_ingline, :rp_inglist_label], enclose: :non_empty }, { match: :rp_ingline, repeating: true, enclose: :non_empty } ],
                  :match_all => :rp_ingline,
                  :under => :rp_inglist,
                  :enclose => :multiple
    },
=begin
        or: [ { # A label followed by one or more ingredient lines, or two or more ingredient lines
                match: [ { or: [:rp_ingline, :rp_inglist_label], enclose: :non_empty }, { match: :rp_ingline, repeating: true, enclose: :non_empty } ],
                :enclose => true
              }
              ,
              { # Within a line, a comma-separated, conjunction-concluded list of ingredients
                :match => :rp_ingline,
                :orlist => :predivide,
                :enclose => true
              }
        ],
    },
=end
    rp_embedded_inglist: {
        match: :rp_ingspec,
        orlist: :predivide,
        token: :rp_inglist
    },
    rp_ingline: {
        match: [
            {
                or: [
                    # If the ingspec fails, try to match noise words at the beginning of the line
                :rp_ingspec, # { match: :rp_ingspec, orlist: true },
                    {
                        match: [
                            {or: ['▢',
                                  /.*:/,
                                  [
                                      {optional: ConditionsSeeker},
                                      /.*/,
                                      /from|of/
                                  ]
                            ], optional: true}, # Discard a colon-terminated label at beginning
                            {match: :rp_ingspec, orlist: true},
                        ]
                    }
                ]
            },
            { optional: :rp_ing_comment }, # Anything can come between the ingredient and the end of line
        ],
        enclose: true,
    },
    rp_inglist_label: { match: nil, inline: true },
    rp_ing_comment: {
        match: nil,
        terminus: "\n"
    }, # NB: matches even if the bound is immediate
    rp_presteps: { tags: 'Condition' }, # There may be one or more presteps (instructions before measuring)
    rp_condition_tag: { tag: 'Condition' }, # There may be one or more presteps (instructions before measuring)
    rp_ingspec: {
        match: [
            {optional: [:rp_amt, {optional: 'each'}]},
            {optional: 'of'},
            { or: [:rp_ingalts, :rp_prepped_ings ] }
        # { or: [ :rp_ingalts, [:rp_presteps, { match: nil, parenthetical: true, optional: true }, :rp_ingalts ] ] }
        ]
    },
    rp_prepped_ings: { or: [ :rp_ingalts, [ :rp_presteps, { match: nil, parenthetical: true, optional: true }, :rp_prepped_ings ] ] },
    rp_ingredient_tag: { tag: 'Ingredient' },
    rp_ingalts: { tags: 'Ingredient' }, # ...an ingredient list of the form 'tag1, tag2, ... and/or tagN'
    rp_amt: {# An Amount is an optional number followed by an optional--possibly qualified--unit--only one required
             match: [
                 [{ match: [:rp_unqualified_amt, { or: ['+', 'plus'], optional: true }, :rp_unqualified_amt], token: :rp_summed_amt }, {match: :rp_altamt, optional: true } ],
                 :rp_qualified_unit,
                 [ { or: [ :rp_range, :rp_num ], optional: true }, { or: [ :rp_qualified_unit, :rp_unit ] }],
                 [{ or: [ :rp_range, :rp_num ] }, { or: [ :rp_qualified_unit, :rp_unit ], optional: true}],
                 {match: AmountSeeker}
             ],
             or: true
    },
    rp_unit_qualifier: { filter: [ { or: %w{ small large massive}, token: :rp_size }, :rp_altamt ] },
    rp_qualified_unit: [ :rp_unit_qualifier, :rp_unit ],
    # A qualified unit is, e.g., '16-ounce can'
    rp_unit: [ { match: :rp_altamt, optional: true }, :rp_unit_tag, { match: :rp_altamt, optional: true } ],
    # An altamt may show up to clarify the amount or qualify the unit
    rp_altamt: {
        match: [
            [ '/', :rp_summed_amt ],
            [ { optional: '(' }, :rp_summed_amt, {match: [';', :rp_summed_amt], optional: true}, { optional: ')' }],
            [ :rp_summed_amt, {match: [';', :rp_summed_amt], optional: true}]
        ],
        or: true
    },
    rp_summed_amt: {# Handling the case of <amt> plus <amt>
                    match: [
                        :rp_unqualified_amt,
                        {:optional => 'plus'},
                        {:optional => :rp_unqualified_amt}
                    ]
    },
    rp_unqualified_amt: {# An Unqualified Amount is a number followed by a unit (only one required)
                         match: [
                             [:rp_num_or_range, { optional: '-' }, :rp_unit_tag],
                             { match: FullAmountSeeker }
                         ],
                         or: true
    },
    rp_num_or_range: { or: [ :rp_range, :rp_num ] },
    rp_num: { match: 'NumberSeeker' },
    rp_range: { match: 'RangeSeeker' },
    rp_unit_tag: { tag: 'Unit' },
    rp_parenthetical: { trigger: '(', match: ParentheticalSeeker }
)
# Each pattern is declared as a pair:
# first, the trigger for the pattern
# second, the pattern to be matched when the trigger is found
Parser.init_triggers([/^\d*(\/{1}\d*|\.\d+)$|^\d+[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]?$|^[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]/, :rp_ingspec ], # A digit triggers parsing for :rp_ingspec
                     [ /^\d+$/, :rp_serves], # A full number triggers match for servings
                     [ /^\d+/, :rp_embedded_inglist], # A full number may also start an embedded ingredient list
                     [Tag.typenum(:Unit), :rp_ingline], # ...so does a Unit
                     [Tag.typenum(:Condition), :rp_ingline] # ...so does a Condition
)
