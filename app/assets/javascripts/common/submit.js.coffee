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
	dlog ||= window.document
	$(dlog).on("ajax:beforeSend", '.submit', RP.submit.beforeSend )
	$(dlog).on("ajax:success", '.submit', RP.submit.success )
	$(dlog).on("ajax:error", '.submit', RP.submit.error )

# Before making a dialog request, see if the dialog is preloaded
RP.submit.beforeSend = (event, xhr, settings) ->
	if (confirm_msg = $(this).data 'confirm-msg') && !confirm(confirm_msg)
		return false
	if wait_msg = $(this).data('wait-msg')
		RP.notifications.wait wait_msg
	true

# Success handler for fetching dialog from server
RP.submit.success = (event, responseData, status, xhr) ->
	RP.notifications.done()
	responseData.how = responseData.how || "modal"
	RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
	RP.process_response responseData, target_modal(event)

RP.submit.error = (event, jqXHR, status, error) ->
	RP.notifications.done()
	responseData = RP.post_error jqXHR
	RP.process_response responseData, target_modal(event)

# Respond to a click by optionally checking for a confirmation, firing a request at the server and appropriately handling the response
RP.submit.go = (event, request) ->
	elmt = event.toElement
	attribs = elmt.attributes
	if attribs.method 
		method = attribs.method.value
	else
		method = "GET"
	data = $(elmt).data();
	if confirm_msg = attribs.confirm && attribs.confirm.value
		bootbox.confirm confirm_msg, (result) ->
			if result
				RP.submit.submit_and_process request, method, data
	else
		RP.submit.submit_and_process request, method, data
	false

RP.submit.submit_and_process = ( request, method, assumptions ) ->
	assumptions = assumptions || {} # No assumptions if absent
	method ||= "GET"
	RP.notifications.wait assumptions.wait_msg
	$.ajax
		type: method,
		dataType: "json",
		url: request,
		error: (jqXHR, textStatus, errorThrown) ->
			$('span.source').text jqXHR.responseText
			RP.notifications.done()
			responseData = RP.post_error jqXHR
			responseData.how = responseData.how || assumptions.how
			RP.process_response responseData
		success: (responseData, statusText, xhr) ->
			# Pass any assumptions into the response data
			RP.notifications.done()
			responseData.how = responseData.how || assumptions.how;
			RP.post_success responseData
			RP.process_response responseData

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
