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
Parser.init_grammar(
    rp_recipelist: {
        match:
            {
                match: [ { optional: :rp_title }, nil ],
                at_css_match: 'h1,h2',
                token: :rp_recipe
            },
        repeating: true
    },
    rp_recipe: {
        match: [
            { optional: :rp_title },
             # Everything after the ingredient list
            { checklist: [
                [ { :repeating => :rp_inglist }, :rp_instructions ],
                { optional: :rp_author },
                { optional: :rp_prep_time },
                { optional: :rp_cook_time },
                { optional: :rp_total_time },
                { optional: :rp_serves },
                { optional: :rp_yield }
            ] },
        ]
    },
    # Hopefully sites will specify how to find the title in the extracted text
    rp_title: {
        in_css_match: 'h1,h2'
    }, # Match all tokens within an <h1> tag
    rp_author: {
        match: [ /^Author:?$/, nil ],
        inline: true
    },
    rp_prep_time: {
        match: [ /^Prep:?$/, { match: /^time:?$/, optional: true }, :rp_time ],
        atline: true
    },
    rp_cook_time: {
        match: [ /^Cook:?$/, { match: /^time:?$/, optional: true }, :rp_time ],
        atline: true
    },
    rp_total_time: {
        match: [ /^Total:?$/, { match: /^time:?$/, optional: true }, :rp_time ],
        atline: true
    },
    rp_time: [ :rp_num, /^(mins?\.?|minutes?)?$/ ],
    rp_yield: {
        match: [ /^(Makes|Yield):?$/i, :rp_amt ],
        atline: true
    },
    rp_serves: {
        match: [ /^Serv(ing|e)s?:?$/, :rp_amt ],
        atline: true
    },
    rp_instructions: nil,
    rp_inglist: {
        match: [ { or: [:rp_ingline, :rp_inglist_label], enclose: :non_empty }, { match: :rp_ingline, repeating: true, enclose: :non_empty } ],
        :in_css_match => 'ul',
    },
    rp_ingline: {
        match: [
            { or: [ /.*:/, [ /.*/, /from/ ] ], optional: true }, # Discard a colon-terminated label at beginning
            { match: :rp_ingspec, orlist: true },
            # {optional: :rp_unit},
            {optional: :rp_ing_comment}, # Anything can come between the ingredient and the end of line
        ],
        enclose: true,
        in_css_match: 'li'
    },
    rp_inglist_label: { match: nil, inline: true },
    rp_ing_comment: {
        match: nil,
        terminus: "\n"
    }, # NB: matches even if the bound is immediate
    rp_amt_with_alt: [:rp_amt, {optional: :rp_altamt}] , # An amount may optionally be followed by an alternative amt enclosed in parentheses
    rp_amt: {# An Amount is a number followed by a unit (only one required)
             match: [
                 [:rp_num_or_range, :rp_unit],
                 :rp_num_or_range,
                 :rp_unit,
                 { match: 'AmountSeeker' }
             ],
             or: true
    },
    rp_altamt: [ '(', :rp_amt, ')' ],
    rp_presteps: { tags: 'Condition' }, # There may be one or more presteps (instructions before measuring)
    rp_condition: { tag: 'Condition' }, # There may be one or more presteps (instructions before measuring)
    rp_ingspec: {
        match: [
            {optional: [:rp_amt_with_alt, {optional: 'each'} ] },
            {optional: 'of'},
            { or: [ :rp_ingalts, [:rp_presteps, { match: nil, parenthetical: true, optional: true }, :rp_ingalts ] ] }
        ]
    },
    rp_ingname: { tag: 'Ingredient' },
    rp_ingalts: { tags: 'Ingredient' }, # ...an ingredient list of the form 'tag1, tag2, ... and/or tagN'
    rp_num_or_range: { or: [ :rp_range, :rp_num ] },
    rp_num: { match: 'NumberSeeker' },
    rp_range: { match: 'RangeSeeker' },
    rp_unit: { tag: 'Unit' }
)
