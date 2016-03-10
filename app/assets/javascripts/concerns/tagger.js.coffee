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
	$('div.header').resize adjustHeader

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

###
RP.tagger.fix_width = ->
	$('ul.token-input-list-facebook li.token-input-input-token-facebook input').css('width', '185px;')
###

check_enabler = ->
	# An enabler specifies an element that will be en/disabled when there are tokens extant
	# e.g., a Submit button that can be enabled when a token has been input
	if selector = $(this).data 'enabler'
		if $(this).tokenInput('get').length == 0
			$(selector).attr 'disabled', 'disabled'
		else
			$(selector).removeAttr 'disabled'

handlerFor = (what, op) ->
	data = $(what).data()
	if hdlr = data.eventHandler || data.eventhandler
		RP.named_function hdlr + '.' + op
	else
		data[op] && RP.named_function data[op]

adjustHeader = ->
	hdr = $('div.header')
	formbottom = $('div.form-group.triggered-form', hdr)[0].getBoundingClientRect().bottom
	# ## Find the padding-top style for the pagelet body, to shift it down--for now and for subsequent loads
	$('div.pagelet-body').css 'padding-top', (formbottom + 'px')
	for ss, ssix in document.styleSheets
		do (ss) ->
			if ss.title == 'pagelet-padding' # Which we have defined in the style declaration in application.html
				for rule, ruleix in ss.rules
					do (rule) ->
						if rule.selectorText == 'div.pagelet-body'
							if rule.style['padding-top'] != formbottom + 'px'
								document.styleSheets[ssix].rules[ruleix].style['padding-top'] = formbottom + 'px'

onReady = (evt) ->
	# if handler = handlerFor this, 'onReady'
	# 	handler()
	setTimeout ->
		inputs = $('div.header li.token-input-input-token-facebook input').width '30px'
		# $('div.header ul.token-input-list-facebook li:first-child input').width '100%'
		adjustHeader()
		$(inputs).first().focus()
	, 50

onAdd = (token) ->
	check_enabler this
	if (container = $(this).closest('div.header'))[0]
		$('li.token-input-input-token-facebook input', container).width '30px'
	adjustHeader()
	if handler = handlerFor this, 'onAdd'
		handler this, token

onDelete = (token) ->
	check_enabler this
	if (container = $(this).closest('div.header'))[0]
		$('li.token-input-input-token-facebook input', container).width '30px'
	adjustHeader()
	if handler = handlerFor this, 'onDelete'
		handler this, token

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
			noResultsText: data.noResultsText || data.noresultstext || "No existing tag found; hit Enter to make it a new tag",
			hintText: data.hintText || data.hinttext || 'Type your own tag(s)',
			zindex: 1052,
			prePopulate: data.pre || "",
			preventDuplicates: true,
			minChars: 2,
			allowFreeTagging: (data.allowFreeTagging != false) && (data.allowfreetagging != false),
			onReady: onReady,
			onAdd: onAdd,
			onDelete: onDelete

		if data.theme != 'list' # To get a list, the theme needs to be unspecified (!)
			options.theme = data.theme || "facebook"
		for attr in ['tokenLimit', 'placeholder']
			if data[attr]
				options[attr] = data[attr]
		if typeof data.hint == 'string'
			options.hintText = data.hint

		$(elmt).tokenInput request, options
		$(elmt).removeClass "token-input-field-pending"
		$(elmt).addClass "token-input-field"
		# Attract entry focus to the appropriate item, after a delay to allow things to settle down
		if elmt.autofocus
			setTimeout (selector) ->
				$(selector).focus()
			, 50, "input#token-input-"+elmt.id

