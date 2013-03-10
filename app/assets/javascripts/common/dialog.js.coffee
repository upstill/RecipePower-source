# Generic dialog management
RP.dialog = RP.dialog || {}

# Hit the server for a dialog via JSON, and run the result
# This function can be tied to a link with only a URL to a controller for generating a dialog.
# We will get the div and run the associated dialog.
RP.dialog.get_and_go = (request, options={}) ->
	# old_dlog is extracted from what triggered this call (if any)
	how = options.how || "modal"
	area = options.area || "floating"
	if request.match /\?/
		q = '&'
	else
		q = '?'
	if !request.match /area=/
		request += q+"area=" + area
		q = '&'
	if !request.match /how=/
		request += q+"how=" + how
	
	odlog = target_modal()
	$.ajax
		type: "GET",
		dataType: "json",
		url: request,
		error: (jqXHR, textStatus, errorThrown) ->
			responseData = post_error jqXHR
			process_response responseData, odlog
		success: (responseData, statusText, xhr) ->
			responseData.how = responseData.how || how;
			post_success responseData # Don't activate any response functions since we're just opening the dialog
			process_response responseData, odlog

RP.dialog.cancel = ->
	if dlog = target_modal()
		close_modal dlog

# Take over a previously-loaded dialog and run it
RP.dialog.run = (dlog) ->
	open_modal dlog, true

# Return the dialog element for the current event target
target_modal = ->
	if (odlog = $('div.dialog.modal')[0]) && $(window.event.currentTarget, odlog)[0]
		return odlog
	
# Handle successful return of a JSON request by running whatever success function
#   obtains, and stashing any resulting code away for invocation after closing the
#   dialog, if any.
post_success = (jsonResponse, dlog, entity) ->

	# Call processor function named in the response
	if closer = RP.named_function jsonResponse.processorFcn
		closer jsonResponse

	# Call the dialog's response function
	if(dlog != undefined) || (entity != undefined)
		notify "save", dlog, entity

	# Stash the result for later processing
	# if dlog != undefined
	#	dialogResult dlog, jsonResponse
	return false

# Handle the error result from either a forms submission or a request of the server
#  by treating the html as code to be rendered and sticking it in an object attached
#  to the dialog, if any.
post_error = ( jqXHR, dlog ) ->
	# Any error page we get we will <try> to present modally
	parsage = {}
	if errtxt = jqXHR.responseText 
		# See if it's valid JSON, b/c you never know...
		try
			parsage = JSON && JSON.parse(errtxt) || $.parseJSON(errtxt)
		catch e
			# Not valid JSON. Maybe it's a page to go to?
			if errtxt.match /^\s*<!DOCTYPE html>/ 
				if newdlog = extract_modal errtxt
					parsage =
						dlog: newdlog
				else
					parsage =  
						page: errtxt 
			else
				# Okay. Assume it's just a string error report
				parsage = 
					errortext: errtxt
	result = null
	# Stash the result in the dialog, if any
	# if dlog != 'undefined'
	# dialogResult dlog, parsage
	return parsage;

# Process response from a request. This will be an object supplied by a JSON request,
# which may include code to be presented along with fields (how and area) telling how
# to present it. The data may also consist of only 'code' if it results from an HTML request
process_response = (responseData, dlog) -> 
	# 'dlog' is the dialog to be replaced, if any
	# Wrapped in 'presentResponse', in the case where we're only presenting the results of the request
	dlog ||= $('div.dialog.modal')[0]
	supplanted = false
	if responseData
		if replacements = responseData.replacements
			i = 0;
			while i < replacements.length
				replacement = replacements[i]
				$(replacement[0]).replaceWith replacement[1]
				i++
		
		if newdlog = responseData.dlog
			placed = replace_modal newdlog, dlog
			supplanted = true
		
		if code = responseData.code
			if newdlog = extract_modal code
				placed = replace_modal newdlog, dlog
				supplanted = true;
			else 
				responseData.page ||= code

		if page = responseData.page
			document.open();
			document.write(page);
			document.close;
			supplanted = true;
		
		post_notifications responseData.notifications
		
		if responseData.done && !supplanted
			close_modal dlog, responseData.notice
			
	return supplanted;

# From a block of code (which may be a whole HTML page), extract a
# modal dialog and return the element
extract_modal = (code) ->
	dom = $(code)
	if $(dom).hasClass "dialog"
		# $(dom).removeClass('modal-pending').addClass('modal')
		return dom[0]
	else
		newdlog = $('div.dialog', dom) # .removeClass('modal-pending').addClass('modal')
		return $(newdlog).detach()[0]

open_modal = (dlog, omit_button) ->
	$(dlog).removeClass('modal-pending').removeClass('hide').addClass('modal')
	notify "load", dlog
	if !omit_button
		buttoncode = '<button type=\"button\" class=\"close\" onclick=\"RP.dialog.cancel()\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button>'
		$('div.modal-header').prepend buttoncode
	if $(dlog).modal
		$(dlog).modal 'show'
	notify "open", dlog
	notify_injector "open", dlog
	dlog

# Remove the dialog and notify its handler prior to removing the element
close_modal = (dlog, epilog) ->
	if($(dlog).modal)
		$(dlog).modal 'hide'
	notify "close", dlog
	$(dlog).remove()
	notify_injector "close", dlog
	if epilog && epilog != ""
		user_note epilog

# Remove the dialog and notify its handler prior to removing the element
cancel_modal = (dlog) ->
	if($(dlog).modal)
		$(dlog).modal 'hide'
	notify "cancel", dlog
	$(dlog).remove()

# Insert a new modal dialog, possibly closing and replacing any predecessor
replace_modal = (newdlog, odlog) ->
	if odlog 
		odlog.parentNode.insertBefore newdlog, odlog
		newdlog = odlog.previousSibling
		cancel_modal odlog
	else
		# Add the new dialog at the end of the page body
		newdlog = document.getElementsByTagName("body")[0].appendChild newdlog
	return open_modal newdlog

# Insert any notifications into 'div.notifications-panel'
post_notifications = (nots) ->
	if nots && panel = $('div.notifications-panel')[0]
		i = 0;
		notsout = "";
		while (i < nots.length)
			nat = nots[i];
			alert_class = nat[0];
			alert_content = nat[1];
			natsout << "<div class=\"alert alert-" + 
			alert_class + 
			"\"><a class=\"close\" data-dismiss=\"alert\">x</a>" +
			alert_content + 
			"</div>"
			i = i+1;
		panel.innerHTML = natsout;

# Filter for submit events, ala javascript. Must return a flag for processing the event normally
filter_submit = (eventdata) ->
	context = this
	dlog = eventdata.data
	if shortcircuit = notify "beforesave", dlog, eventdata.currentTarget
		eventdata.preventDefault()
		process_response shortcircuit
	else
		# Okay to submit
		# To sort out errors from subsequent dialogs, we submit the form synchronously
		#  and use the result to determine whether to do normal forms processing.
		$(context).ajaxSubmit
			async: false,
			dataType: 'json',
			error: (jqXHR, textStatus, errorThrown) ->
				jsonout = post_error jqXHR, dlog # Show the error message in the dialog
				eventdata.preventDefault()
				return !process_response jsonout, dlog
			success: (responseData, statusText, xhr, form) ->
				post_success responseData, dlog, form
				eventdata.preventDefault()
				sorted = process_response responseData, dlog
				if responseData.success == false
					# Equivalent to an error, so just return
					return sorted
	return false 

manager_of = (dlog) ->
	# Look for a manager using the dialog's class name
	if dlog 
		if mgr_name = $(dlog).data 'manager'
			return RP[mgr_name]
		if classname = $(dlog).attr 'class'
			classList = classname.split /\s+/ 
			for mgr_name in classList
				if mgr_name != "dialog" && RP[mgr_name] 
					return RP[mgr_name]
	return null	

# Actually redundant wrt notify; here for legacy of RPDialog
RP.dialog.notify_manager = (method, dlog) ->
	mgr = manager_of dlog
	if mgr && mgr[method]
		mgr[method](dlog)

user_note = (msg) ->
	jNotify msg,
		HorizontalPosition: 'center', 
		VerticalPosition: 'top', 
		TimeShown: 1200
	
# Determine either the callback (kind = "Fcn") or the message (kind="Msg")
#  for a given event type from among:
# load
# beforesave
# save
# cancel
# close
# If there's a function for the event in the hooks, call it
# If it doesn't exist, or returns false when called, and there's a message for the event in the hooks, post it
# If it doesn't exist, or returns false when called, and there's a handler for the manager of the dialog, call it
# If it doesn't exist, or returns false when called, apply the default event handler 
notify = (what, dlog, entity) ->
	hooks = $(entity || dlog).data("hooks");
	fcn_name = what+"Fcn";
	msg_name = what+"Msg";
	# If the entity or the dialog have hooks declared, use them
	if hooks
		if hooks.hasOwnProperty msg_name
			user_note hooks[msg_name]
		if hooks.hasOwnProperty fcn_name
			fcn = RP.named_function hooks[fcn_name]
			return fcn dlog # We want an error if the function doesn't exist
	
	# If there's a manager module with a responder, call it
	if (mgr = manager_of dlog) && (fcn = mgr[what] || mgr["on"+what])
		return fcn dlog
	
	# Otherwise, run the default
	switch what
		when "open", "onopen"
			# onopen handler that sets a Boostrap dialog up to run modally: Trap the 
			# form submission event to give us a chance to get JSON data and inject it into the page
			# rather than do a full page reload.
			if !$(dlog).hasClass "modal" # The modality may be hidden if prepared for a page
				$(dlog).addClass "modal"
			$(dlog).removeClass "hide"
			$(dlog).on 'shown', ->
				$('textarea', dlog).focus()
			# Forms submissions that expect JSON structured data will be handled here:
			$('form', dlog).submit dlog, filter_submit
		# when "load", "onload"
		# when "beforesave"
		# when "save", "onsave"
		# when "cancel", "oncancel"
		# when "close", "onclose"
	return

# Special handler for dialogs imbedded in an iframe. See 'injector.js'
notify_injector = (what, dlog) ->
	if fcn = RP.named_function what+"_dialog"
		fcn dlog
	
# Public convenience methods for handling events
RP.dialog.onopen = (dlog, entity) ->
	notify 'open', dlog, entity

RP.dialog.onclose = (dlog, entity) ->
	notify 'close', dlog, entity

RP.dialog.onload = (dlog, entity) ->
	notify 'load', dlog, entity

RP.dialog.onsave = (dlog, entity) ->
	notify 'save', dlog, entity

