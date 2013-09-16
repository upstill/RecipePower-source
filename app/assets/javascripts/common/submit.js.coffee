RP.submit = RP.submit || {}

# Handle submission links
RP.submit.bind = (dlog) ->
	dlog ||= window.document
	$(dlog).on("ajax:beforeSend", '.talky-submit', RP.submit.beforeSend )
	$(dlog).on("ajax:success", '.talky-submit', RP.submit.success )
	$(dlog).on("ajax:error", '.talky-submit', RP.submit.error )

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
	odlog = target_modal event
	RP.process_response responseData, odlog

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
