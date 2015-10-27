# Support for applying tags

RP.tagger = RP.tagger || {}

jQuery ->
	RP.tagger.onopen()
	$('.token-input-field-pending').on "load", (event) ->
		c=2
		false
	$('body').on "load", '.stream-body', (event) ->
		c=3
		false
	$('body').on "load", '.token-input-field-pending', (event) ->
		c=3
		false
	$('div.stream-body').on "load", (event) ->
		c=3
		false
	$('div.stream-body').on "load", '.token-input-field-pending', (event) ->
		c=3
		false

# Set up an input element for tagging by populating the data of the element as specified
RP.tagger.init = (selector, data) ->
  $(selector).addClass "token-input-field-pending"
  for prop, value of data
    $(selector).data prop, value

# When a tagging field is loaded, get tokenInput running, either from the 
# element's data field or the imposed harddata
RP.tagger.onopen = (selector = '.token-input-field-pending') ->
	$(selector).each ->
		RP.tagger.setup this

RP.tagger.onload = (event) ->
	RP.tagger.setup event.target

RP.tagger.querify = ->
	RP.querify.propagate this, { querytags: $(this)[0].value }

RP.tagger.select_type = (event) ->
	RP.querify.propagate event.target, { tagtype: event.target.value }

RP.tagger.onReady = ->
	$('li.token-input-input-token input').trigger 'click'

# Use data attached to the element to initiate tokenInput
RP.tagger.setup = (elmt) ->
	# In case the token-input element is a child of elmt
	if elmt # Only proceed for a defined element
		if ! $(elmt).hasClass 'token-input-field-pending'
			elmt = $('.token-input-field-pending', elmt)
		data = $(elmt).data() || {}
		request = data.request || "/tags/match.json"
		if data.query
			qstr = "?"
			if typeof data.query == 'string'
				qstr += data.query
			else
				for attrname, attrvalue of data.query
					qstr += "&" unless qstr=="?"
					qstr += encodeURIComponent(attrname) + "=" + encodeURIComponent(attrvalue)
			request += qstr # encodeURIComponent(data.query)
		options =
			crossDomain: false,
			noResultsText: data.noResultsText || "No existing tag found; hit Enter to make it a new tag",
			hintText: data.hint_text || 'Type your own tag(s)',
			zindex: 1052,
			prePopulate: data.pre || "",
			preventDuplicates: true,
			minChars: 2,
			allowFreeTagging: (data.free_tagging != false)
		if data.event_handler
			options.onAdd = RP.named_function(data.event_handler + '.onAdd')
			options.onDelete = RP.named_function(data.event_handler + '.onDelete')
			options.onReady = RP.named_function(data.event_handler + '.onReady')

		if data.theme != 'list' # To get a list, the theme needs to be unspecified (!)
			options.theme = data.theme || "facebook"
		for attr in ['tokenLimit', 'placeholder']
			if data[attr]
				options[attr] = data[attr]
		for attr in ['onAdd', 'onDelete', 'onReady']
			if data[attr] && func = RP.named_function data[attr]
				options[attr] = func
		if typeof data.hint == 'string'
			options.hintText = data.hint

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
		# Attract entry focus to the appropriate item, after a delay to allow things to settle down
		if elmt.autofocus
			setTimeout (selector) ->
				$(selector).focus()
			, 50, "input#token-input-"+elmt.id

