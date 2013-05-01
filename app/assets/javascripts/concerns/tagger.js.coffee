# Support for applying tags

RP.tagger = RP.tagger || {}

RP.tagger.init = (selector, data) ->
	for prop, value of data
		$(selector).data prop, value

RP.tagger.onload = (selector=".tagging_field", options={}) ->
	debugger
	$(selector).each ->
		hint = $(this).data("hint") || "Type your own tag(s)"
		if query = $(this).data("query")
			query = "?"+query
		else
			query = "" # ...for any restrictions on the tag query
		$(this).tokenInput("/tags/match.json"+query,
			crossDomain: false,
			noResultsText: "No matching tag found; hit Enter to make it a tag",
			hintText: hint,
			prePopulate: $(this).data("pre"),
			theme: "facebook",
			preventDuplicates: true,
			allowFreeTagging: true
		)
  