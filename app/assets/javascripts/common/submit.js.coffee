# This module supports submitting to the server by various means:
# * JRS remote-request handling for any link with the 'submit' class
# * a click-event handler (RP.submit.go)
# * a request submit-and-process function (RP.submit.submit_and_process
# All three methods support a prior confirmation dialog and a popup advisory
#   that the request is in process.
# In all cases, the submission is for JSON data that is then processed
#   via standard RP response handling.

RP.submit = RP.submit || {}

jQuery ->
	RP.submit.bind()
	$(document).on "ajax:beforeSend", 'form.submit', RP.submit.beforeSend
	$(document).on "ajax:success", 'form.submit', RP.submit.success
	$(document).on "ajax:error", 'form.submit', RP.submit.error

# Handle submission links
RP.submit.bind = (dlog) ->
	dlog ||= $('body') # window.document
	# Set up processing for click events on links with a 'submit' class
	$(dlog).on "click", 'a.submit', RP.submit.onClick
	$('.preload', dlog).each (ix, elmt) ->
		preload elmt
	$('.trigger', dlog).each (ix, elmt) ->
		fire elmt

# Respond to a change of selection value by submitting the enclosing form
RP.submit.onselect = (event) ->
	formelmt = RP.findEnclosing 'FORM', event.currentTarget
	# On selecting a tag type, clear the associated tokenInput, which may have tokens of diff. types
	$('.token-input-field', formelmt).tokenInput 'clear'
	$(formelmt).submit()

# Respond to a change of tokeninput field  by submitting the enclosing form
RP.submit.ontokenchange = ->
	formelmt = RP.findEnclosing 'FORM', this[0]
	$(formelmt).submit()

# Respond to a click on a '.submit' element by optionally checking for a confirmation, firing a request at the server and appropriately handling the response
RP.submit.onClick = (event) ->
	fire event.currentTarget # event.toElement
	false

# preload ensures that the results of the query are available
preload = (elmt) ->
	if $(elmt).hasClass 'loading'
		return;
	data = $(elmt).data() || {}
	# Four ways to short-circuit a request (and to satisfy the preload items):
	# 1: a dialog has been preloaded into data.preloaded
	# 2: the response has been preloaded into data.response
	# 3: data.template leads to a dialog template (selector and subs fields
	# 4: data.selector finds a DOM element for direct (untemplated) use
	# The element will store either a 'response' object or a 'preloaded' dialog element
	if data.preloaded
		return # data.preloaded
	if responseData = data.response
		return # responseData.dlog || responseData
	if (templateData = data.template) && templateData.subs
		return # interpolated
	if data.selector && (ndlog = $(data.selector)[0]) # If dialog is already loaded as a DOM entity, return it
		return # ndlog
	# Finally, there is no preloaded recourse, so we submit the request
	$(elmt).addClass 'loading'
	$.ajax
		type: "GET",
		dataType: "json",
		contentType: "application/json",
		url: elmt.attributes.href.value,
		error: (jqXHR, statusText, errorThrown) ->
			responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
			handleResponse elmt, responseData, statusText, errorThrown
		success: (responseData, statusText, xhr) ->
			handleResponse elmt, responseData, statusText, xhr

fire = (elmt) ->
	if $(elmt).hasClass( "loading") # This may already be loading
		handleEnclosingNavTab elmt
		$(elmt).addClass('trigger') # Mark for immediate opening
	else if proceedWithConfirmation(elmt)
		# If the submission is made from a top-level menu, make the menu active
		handleEnclosingNavTab elmt
		RP.submit.submit_and_process elmt.attributes.href.value, elmt, $(elmt).data('method')

handleEnclosingNavTab = (menuElmt) ->
	if !$(menuElmt).hasClass "transient" # So marked if its selection will not affect what menu element is active
		while menuElmt && !$(menuElmt).hasClass "master-navtab"
			menuElmt = RP.findEnclosing "LI", menuElmt
		if menuElmt # Select this menu element exclusively
			$('.master-navtab').removeClass "active"
			$('.master-navtab a').css 'color','#999'
			$(menuElmt).addClass "active"
			$('>a', menuElmt).css 'color','white'

proceedWithConfirmation = (elmt) ->
	!(confirm_msg = $(elmt).data 'confirmMsg') || confirm confirm_msg

# Master function for submitting AJAX, perhaps in the context of a DOM element that triggered it
# Elements may fire off requests by:
# -- being clicked (click events get here by association with the 'submit' class
# -- having a 'preload' class, which attaches the result of the request to the element pending a subsequent click
RP.submit.submit_and_process = ( request, elmt, method="GET" ) ->
	if typeof(method) == "object"
		data = method
		method = "POST"
	else
		data = null
	$(elmt).addClass 'trigger'
	unless elmt && ($(elmt).hasClass('loading') || (preloaded = shortCircuit elmt))
		$(elmt).addClass 'loading'
		ajdata =
			type: method,
			dataType: "json",
			contentType: "application/json",
			url: request,
			error: (jqXHR, statusText, errorThrown) ->
				# TODO Not actually posting an error for the user
				responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
				handleResponse elmt, responseData, statusText, errorThrown
			success: (responseData, statusText, xhr) ->
				handleResponse elmt, responseData, statusText, xhr
		if data != null
			ajdata.data = data
		$.ajax ajdata
	if preloaded
		# The preloaded data is either a DOM element for a dialog, a source string for the dialog, or a responseData structure
		if preloaded.done || preloaded.dlog || preloaded.code || preloaded.replacements
			handleResponse elmt, preloaded
		else if typeof(ndlog = preloaded) == "string" || (ndlog = $(preloaded)[0]) # Got a string or a DOM element => run dialog
			$(elmt).removeClass 'trigger'
			RP.dialog.push_modal ndlog, RP.dialog.enclosing_modal(elmt)

shortCircuit = (elmt) ->
	data = (elmt && $(elmt).data()) || {}
	RP.notifications.wait data.waitMsg # If any
	# Four ways to short-circuit a request (and to satisfy the preloaded items):
	# 1: a dialog has been preloaded into data.preloaded
	# 2: the response has been preloaded into data.response
	# 3: data.template leads to a dialog template (selector and subs fields
	# 4: data.selector finds a DOM element for direct (untemplated) use
	if elmt
		# The element will store either a 'response' object or a 'preloaded' dialog element
		if ndlog = data.preloaded || ((responseData = data.response) && responseData.dlog)
			return ndlog;
		else if responseData
			return responseData
		if (templateData = data.template) && templateData.subs && (interpolated = RP.templates.find_and_interpolate(templateData))
			return interpolated
	if data.selector && (ndlog = $(data.selector)[0]) # If dialog is already loaded as a DOM element, return it
		return ndlog
	false

# Apply a response to the element's request, whether preloaded or freshly arrived, or even whether the element exists or not
handleResponse = (elmt, responseData, status, xhr) ->
	RP.notifications.done()
	# A response has come in, so the element is no longer loading
	$(elmt).removeClass 'loading'
	# Elements that preload their query results stash them away, unless they also have the 'trigger' class
	immediate = $(elmt).hasClass 'trigger'
	if elmt && !immediate
		# Save for later if this is a preload that's not triggering now
		$(elmt).data "response", responseData
		$(elmt).addClass 'loaded'
	else
		$(elmt).removeClass 'trigger'
		RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
		RP.process_response responseData, RP.dialog.enclosing_modal(elmt)

# Before making a form submission, see if the dialog is preloaded
RP.submit.beforeSend = (event, xhr, settings) ->
	elmt = event.currentTarget
	# If the submission is made from a top-level menu, make the menu active
	if proceedWithConfirmation elmt
		RP.notifications.wait $(elmt).data 'waitMsg'
		true

# Success handler for fetching dialog from server
RP.submit.success = (event, responseData, statusText, xhr) ->
	RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
	RP.process_response responseData, RP.dialog.enclosing_modal(event.currentTarget)

RP.submit.error = (event, jqXHR, statusText, errorThrown) ->
	# TODO Not actually posting an error for the user
	RP.notifications.done()
	if responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
		RP.process_response responseData, RP.dialog.enclosing_modal(event.currentTarget)
