# Support for applying tags

RP.tagger = RP.tagger || {}

# Set up an input element for tagging
RP.tagger.init = (selector, data) ->
  $(selector).addClass "token-input-field-pending"
  for prop, value of data
    $(selector).data prop, value

# When a tagging field is loaded, get tokenInput running, either from the 
# element's data field or the imposed harddata
RP.tagger.onopen = (selector = '.token-input-field-pending') ->
	$(selector).each ->
		RP.tagger.setup this

# Use data attached to the element to initiate tokenInput
RP.tagger.setup = (elmt) ->
	data = $(elmt).data() || {}
	request = data.request || "/tags/match.json"
	if data.query
		request += "?"+data.query # encodeURIComponent(data.query)
	options = 
		crossDomain: false,
		noResultsText: data.noResultsText || "No existing tag found; hit Enter to make it a new tag",
		hintText: data.hint || "Type your own tag(s)",
		zindex: 1052,
		prePopulate: data.pre || "",
		theme: "facebook",
		preventDuplicates: true,
		minChars: 2,
		allowFreeTagging: (data.freeTagging != false)
	for attr in ['tokenLimit']
		if data[attr]
			options[attr] = data[attr]

	# onAdd and onDelete specify functions to be called when the selection changes
	if data.onAdd
		options.onAdd = RP.named_function data.onAdd
	if data.onDelete
		options.onDelete = RP.named_function data.onDelete

	# An enabler specifies an element that will be en/disabled when there are tokens extant
	# e.g., a Submit button that can be enabled when a token has been input
	if data.enabler?
		options.onAdd = options.onDelete = (item) ->
			selector = $(this).data "enabler"
			if $(this).tokenInput("get").length == 0
				$(selector).attr "disabled","disabled"
			else
		    $(selector).removeAttr "disabled"
	$(elmt).tokenInput request, options
	$(elmt).removeClass "token-input-field-pending"
	$(elmt).addClass "token-input-field"


