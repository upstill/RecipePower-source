# Support for applying tags

RP.tagger = RP.tagger || {}

RP.tagger.init = (selector, data) ->
	for prop, value of data
		$(selector).data prop, value

# When a tagging field is loaded, get tokenInput running, either from the 
# element's data field or the imposed harddata
RP.tagger.onload = (selector=".tagging_field") ->
	$(selector).each ->
		data = $(this).data() || {}
		request = "/tags/match.json"
		if data.query
			request += "?"+encodeURIComponent(data.query)
		$(this).tokenInput(request,
			crossDomain: false,
			noResultsText: data.noResultsText || "No matching tag found; hit Enter to make it a tag",
			hintText: data.hint || "Type your own tag(s)",
			prePopulate: data.pre,
			theme: "facebook",
			preventDuplicates: true,
			allowFreeTagging: true
		)
  