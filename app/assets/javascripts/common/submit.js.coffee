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

# Handle submission links
RP.submit.bind = (dlog) ->
	dlog ||= $('body') # window.document
	# Set up processing for click events on links with a 'submit' class
	$(dlog).on "click", 'a.submit', RP.submit.onClick
	$('.preload', dlog).each (ix, elmt) ->
		fire elmt
	$(dlog).on "ajax:beforeSend", 'form.submit', RP.submit.beforeSend
	$(dlog).on "ajax:success", 'form.submit', RP.submit.success
	$(dlog).on "ajax:error", 'form.submit', RP.submit.error

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

fire = (elmt) ->
	if $(elmt).hasClass( "loading") # This may already be loading
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
	unless elmt && ($(elmt).hasClass('loading') || (preload = shortCircuit(request, elmt)))
		$(elmt).addClass 'loading'
		ajdata =
			type: method,
			dataType: "json",
			url: request,
			error: (jqXHR, statusText, errorThrown) ->
				# TODO Not actually posting an error for the user
				$(elmt).removeClass 'loading'
				responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
				handleResponse elmt, responseData, statusText, errorThrown
			success: (responseData, statusText, xhr) ->
				$(elmt).removeClass 'loading'
				handleResponse elmt, responseData, statusText, xhr
		if data != null
			ajdata.data = data
		$.ajax ajdata
	if preload
		# The preloaded data is either a DOM element for a dialog, a source string for the dialog, or a responseData structure
		if typeof(preload) == "string"
			RP.dialog.push_modal preload, RP.dialog.enclosing_modal(elmt)
		else if preload.done || preload.dlog || preload.code || preload.replacements
			handleResponse elmt, preload
		else if ndlog = $(preload)[0] # It's a DOM element
			RP.dialog.push_modal ndlog, RP.dialog.enclosing_modal(elmt)

shortCircuit = (request, elmt) ->
	data = (elmt && $(elmt).data()) || {}
	RP.notifications.wait data.waitMsg # If any
	odlog = RP.dialog.enclosing_modal elmt
	# Three ways to short-circuit a request:
	# 1: a dialog has been preloaded into data.preloaded
	# 2: the response has been preloaded into data.response
	# 3: data.selector leads to a dialog somewhere in the DOM
	if elmt
		if $(elmt).hasClass("preload")
			# The element will store either a 'response' object or a 'preloaded' dialog element
			if ndlog = data.preloaded || ((responseData = data.response) && responseData.dlog)
				# RP.dialog.push_modal ndlog, odlog
				return ndlog;
			else if responseData
				# RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
				# RP.process_response responseData
				# RP.state.onAJAXSuccess event
				$(elmt).data 'response', null
				return responseData
		if (templateData = data.template) && templateData.subs
			if interpolated = RP.templates.find_and_interpolate(templateData)
				return interpolated
	if data.selector && (ndlog = $(data.selector)[0]) # If dialog is already loaded, replace the responding dialog
		$(elmt).removeClass 'trigger'
		return ndlog
		# RP.dialog.replace_modal ndlog, odlog # Will close any existing open dialog
		# RP.state.postDialog ndlog, request, (elmt && elmt.innerText) # RP.state.onAJAXSuccess event
		# return true;
	false

handleResponse = (elmt, responseData, status, xhr) ->
	# Pass any data into the response data
	RP.notifications.done()
	# Elements that preload their query results stash it away, unless they also have the 'trigger' class
	if elmt && ($(elmt).hasClass 'preload') && !($(elmt).hasClass 'trigger')
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
