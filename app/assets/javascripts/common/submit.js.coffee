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
	# Designate RP.submit.onLoad() to handle load events for '.preload' links
	$(dlog).on "preload", 'a.preload', RP.submit.onLoad
	# ...annnnnd FIRE!
	$('.preload', dlog).trigger "preload"
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
	elmt = event.currentTarget # event.toElement
	# If the submission is made from a top-level menu, make the menu active
	if proceedWithConfirmation elmt
		handleEnclosingNavTab elmt
		# $(elmt).addClass('trigger') # Mark for immediate opening
		RP.submit.submit_and_process elmt.attributes.href.value, elmt, $(elmt).data('method')
	false

handleEnclosingNavTab = (menuElmt) ->
	while menuElmt && !$(menuElmt).hasClass "master-navtab"
		menuElmt = RP.findEnclosing "LI", menuElmt
	if menuElmt # Select this menu element exclusively
		$('.master-navtab').removeClass "active"
		$('.master-navtab a').css 'color','#999'
		$(menuElmt).addClass "active"
		$('>a', menuElmt).css 'color','white'

proceedWithConfirmation = (elmt) ->
	!(confirm_msg = $(elmt).data 'confirm-msg') || confirm confirm_msg

# Notify elmts to preload their query results
RP.submit.onLoad = (event) ->
	RP.submit.fromLink event.currentTarget
	false

RP.submit.fromLink = (elmt) ->
	RP.submit.submit_and_process elmt.attributes.href.value, elmt, $(elmt).data('method')

# Master function for submitting AJAX, perhaps in the context of a DOM element that triggered it
# Elements may fire off requests by:
# -- being clicked (click events get here by association with the 'submit' class
# -- having a 'preload' class, which attaches the result of the request to the element pending a subsequent click
RP.submit.submit_and_process = ( request, elmt, method="GET" ) ->
	unless shortCircuit request, elmt
		$.ajax
			type: method,
			dataType: "json",
			url: request,
			error: (jqXHR, statusText, errorThrown) ->
				# TODO Not actually posting an error for the user
				if responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
					handleResponse elmt, responseData, statusText, errorThrown
			success: (responseData, statusText, xhr) ->
				handleResponse elmt, responseData, statusText, xhr

shortCircuit = (request, elmt) ->
	if elmt && $(elmt).hasClass 'loading'# Prevent submitting the link twice
		return true
	data = (elmt && $(elmt).data()) || {}
	RP.notifications.wait data['wait-msg'] # If any
	odlog = RP.dialog.enclosing_modal elmt
	if elmt && $(elmt).hasClass("preload")
		# The element will store either a 'response' object or a 'preloaded' dialog element
		responseData = data.response
		if ndlog = data.preloaded || (responseData && responseData.dlog)
			RP.dialog.push_modal ndlog, odlog
			return true;
		else if responseData
			RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
			RP.process_response responseData
			RP.state.onAJAXSuccess event
			$(elmt).data 'response', null
			return true;
		$(elmt).addClass 'loading'
	else if data.selector && (ndlog = $(data.selector)[0]) # If dialog is already loaded, replace the responding dialog
		$(elmt).removeClass 'trigger'
		RP.dialog.replace_modal ndlog, odlog # Will close any existing open dialog
		RP.state.postDialog ndlog, request, (elmt && elmt.innerText) # RP.state.onAJAXSuccess event
		return true;
	false

handleResponse = (elmt, responseData, status, xhr) ->
	# Pass any data into the response data
	RP.notifications.done()
	$(elmt).removeClass 'loading'
	# responseData.how ||= data.how;
	# Elements that preload their query results stash it away, unless they also have the 'trigger' class
	if elmt && !($(elmt).hasClass 'trigger')
		# Save for later if not triggering now
		$(elmt).data "response", responseData
		$(elmt).addClass 'loaded'
	else
		RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
		RP.process_response responseData, RP.dialog.enclosing_modal(elmt)

# Before making a form submission, see if the dialog is preloaded
RP.submit.beforeSend = (event, xhr, settings) ->
	elmt = event.currentTarget
	# If the submission is made from a top-level menu, make the menu active
	if proceedWithConfirmation elmt
		RP.notifications.wait $(elmt).data 'wait-msg'
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

### The code below pertains to date-sensitive updates. It's not used and probably not useable

# Linkable function to skin the get_content function. Associated link should have data values as above
RP.submit.get_content = (url, link) ->
	jQuery.ajax "/collection/update", { type: "POST" }
	last_modified = $(link).data 'last_modified'
	get_content url, last_modified,
		hold_msg: $(link).data('hold_msg'),
		msg_selector: $(link).data('msg_selector') || link,
		dataType: $(link).data('dataType'),
		type: $(link).data('type'),
		refresh: $(link).data('refresh'),
		contents_selector: $(link).data('contents_selector')

# Asynchronous method to replace content via request from server.
# A polling loop periodically checks for changes, replacing the whole element when
# complete (for HTML requests) or replacing selected elements (for JSON)
# Options determine:
#   -- dataType and method of the request (default JSON GET)
#   -- message to be displayed before completion (default "Updating...")
#   -- CSS selector of element to receive updating message ("#notifications_panel")
#   -- contents_selector: CSS selector of element to be replaced by HTML result
#   -- update: boolean indicating that the requisite item should be updated
get_content = (url, last_modified, options) ->
	hold_msg = options.hold_msg || "Checking for updates..."
	msg_selector = options.msg_selector || "#notifications-panel"

	ajax_options =
		dataType: options.dataType || "html",
		type: options.type || "get",
	# ajax_options.data = "refresh=true" if options.refresh

	processing_options =
		contents_selector: options.contents_selector || "div.content"

	# Notify the user of the ongoing process by replacing the message selector with a bootstrap notification
	$(msg_selector).replaceWith "<span>"+hold_msg+"</span>"

	ajax_options.requestHeaders ||= {}
	ajax_options.requestHeaders['If-Modified-Since'] = last_modified
	# ajax_options.requestHeaders['X-CSRF-Token'] ||= $('meta[name="csrf-token"]').attr 'content'
	# ajax_options.cache = false

	poll_for_update url, ajax_options, processing_options


poll_for_update = (url, ajax_options, processing_options) ->
	ajax_options.success ||= (resp, succ, xhr) ->
		if xhr.status == 204 # Use no-content status to indicate we're waiting for update
			setTimeout (-> poll_for_update url, ajax_options, processing_options), 1000
		else if xhr.status == 200
			if ajax_options.dataType == "html"
				$(processing_options.contents_selector).html xhr.responseText
		else
			RP.notifications.post "Sorry: got an error trying to update", "flash-error"

	ajax_options.error ||= (jqXHR, textStatus, errorThrown) ->
		# Threw an error.  We got either replacement HTML (because the controller couldn't produce JSON)
		# or a simple message string (to be placed into the notifications panel)
		dom = $(jqXHR.responseText)
		if dom.length > 0
			RP.notifications.post "Update complete!", "flash-alert"
			$(processing_options.contents_selector).replaceWith dom
		else
			RP.notifications.post jqXHR.responseText, "flash-alert"

	jQuery.ajax url, ajax_options # setTimeout jQuery.ajax(url, ajax_options), 1000

###
