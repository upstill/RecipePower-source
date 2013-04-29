# Support for applying tags

RP.tagger = RP.tagger || {}

RP.tagger.init = (selector, jsondata) ->
	$(selector).data "pre", jsondata

RP.tagger.onload = (selector, options={}) ->
	hint = options.hint || "Type your own tag(s)"
	$(selector).tokenInput("/tags/match.json",
		crossDomain: false,
		noResultsText: "No matching tag found; hit Enter to make it a tag",
		hintText: hint,
		prePopulate: $(selector).data("pre"),
		theme: "facebook",
		preventDuplicates: true,
		allowFreeTagging: true
	)
  