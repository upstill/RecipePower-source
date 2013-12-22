RP.get_content ||= {}

jQuery ->
	$(document).on("ajax:beforeSend", '.get-content', RP.get_content.beforeSend)
	$(document).on("ajax:success", '.get-content', RP.get_content.success)
	$(document).on("ajax:error", '.get-content', RP.get_content.error)

RP.get_content.assimilate = (contentstr)  ->
	obj = JSON.parse contentstr.replace(/&quot;/g,'"')
	RP.process_response obj

# Hit the server for a dialog via JSON, and run the result
# This function can be tied to a link with only a URL to a controller for generating a dialog.
# We will get the div and run the associated dialog.
RP.get_content.go = (event, request, selector) ->
	# old_dlog is extracted from what triggered this call (if any)
	if (!event) || RP.get_content.beforeSend event
		$.ajax
			type: "GET",
			dataType: "json",
			url: request,
			error: (jqXHR, textStatus, errorThrown) ->
				RP.get_content.error event, jqXHR, textStatus, errorThrown
			success: (responseData, statusText, xhr) ->
				RP.get_content.success event, responseData, statusText, xhr

# Before making a dialog request, see if the dialog is preloaded
RP.get_content.beforeSend = (event, xhr, settings) ->
	selector = $(this).data 'selector'
	if selector && (ndlog = $(selector)[0]) # If dialog already loaded, replace the responding dialog
		return false;
	else
		return true;

# Success handler for fetching get_content from server
RP.get_content.success = (event, responseData, status, xhr) ->
	RP.post_success responseData
	RP.process_response responseData # , target_modal(event)

RP.get_content.error = (event, jqXHR, status, error) ->
	responseData = RP.post_error jqXHR
	# odlog = target_modal event
	RP.process_response responseData # , odlog
