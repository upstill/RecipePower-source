# Support for applying tags

RP.tagger = RP.tagger || {}

RP.tagger.init = (selector, data) ->
	for prop, value of data
		$(selector).data prop, value

# When a tagging field is loaded, get tokenInput running, either from the 
# element's data field or the imposed harddata
RP.tagger.onopen = (selector=".tagging_field") ->
	$(selector).each -> 
		RP.tagger.setup this

# Use data attached to the element to initialize tagging
RP.tagger.setup = (elmt) ->
	data = $(elmt).data() || {}
	request = data.request || "/tags/match.json"
	if data.query
		request += "?"+encodeURIComponent(data.query)
	$(elmt).tokenInput(request,
		crossDomain: false,
		noResultsText: data.noResultsText || "No existing tag found; hit Enter to make it a new tag",
		hintText: data.hint || "Type your own tag(s)",
		zindex: 1052,
		prePopulate: data.pre,
		theme: "facebook",
		preventDuplicates: true,
		allowFreeTagging: true
	)
  