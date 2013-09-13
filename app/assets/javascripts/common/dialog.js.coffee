# Generic dialog management
RP.dialog = RP.dialog || {}

jQuery ->
	RP.dialog.arm_links()
	$(document).on("ajax:beforeSend", '.dialog-run', RP.dialog.beforeSend )
	$(document).on("ajax:success", '.dialog-run', RP.dialog.success )
	$(document).on("ajax:error", '.dialog-run', RP.dialog.error )

RP.dialog.arm_links = (dlog) ->
	dlog ||= window
	$('input.cancel', dlog).click RP.dialog.cancel
	$('a.dialog-cancel-button', dlog).click RP.dialog.cancel

# Before making a dialog request, see if the dialog is preloaded
RP.dialog.beforeSend = (event, xhr, settings) ->
	debugger
	selector = $(this).data 'selector'
	odlog = target_modal event
	if selector && (ndlog = $(selector)[0]) # If dialog already loaded, replace the responding dialog
		RP.dialog.replace_modal ndlog, odlog
		return false;
	else
		return true;
	
# Success handler for fetching dialog from server
RP.dialog.success = (event, responseData, status, xhr) ->
	debugger
	responseData.how = responseData.how || "modal"
	RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
	RP.process_response responseData, target_modal(event)
	
RP.dialog.error = (event, jqXHR, status, error) ->
	debugger
	responseData = RP.post_error jqXHR
	odlog = target_modal event
	RP.process_response responseData, odlog

# Hit the server for a dialog via JSON, and run the result
# This function can be tied to a link with only a URL to a controller for generating a dialog.
# We will get the div and run the associated dialog.
RP.dialog.get_and_go = (event, request, selector) ->
	# old_dlog is extracted from what triggered this call (if any)
	debugger
	if event
		odlog = target_modal(event)
	else
		odlog = null
	if selector && (ndlog = $(selector)[0]) # If dialog already loaded, replace the responding dialog
		RP.dialog.replace_modal ndlog, odlog
	else
		# Ensure that the request has :area and :how query parameters
		how = "modal"
		area = "floating"
		if request.match /\?/
			q = '&'
		else
			q = '?'
		if !request.match /area=/
			request += q+"area=" + area
			q = '&'
		if !request.match /how=/
			request += q+"how=" + how
		$.ajax
			type: "GET",
			dataType: "json",
			url: request,
			error: (jqXHR, textStatus, errorThrown) ->
				RP.dialog.error event, jqXHR, textStatus, errorThrown
			success: (responseData, statusText, xhr) ->
				RP.dialog.success event, responseData, statusText, xhr

RP.dialog.cancel = (event) ->
	if event
		dlog = target_modal(event)
		event.preventDefault();			
	else
		dlog = $('div.dialog')[0]
	if dlog
		RP.dialog.close_modal dlog

# Take over a previously-loaded dialog and run it
RP.dialog.run = (dlog) ->
	open_modal dlog, true

# From a block of code (which may be a whole HTML page), extract a
# modal dialog and return the element
RP.dialog.extract_modal = (code) ->
	# Assuming the code is a fragment for the dialog...
	wrapper = document.createElement('div');
	wrapper.innerHTML = code;
	dlog = wrapper.firstElementChild
	if $(dlog).hasClass('dialog')
		wrapper.removeChild dlog
		return dlog 
	# ...It may also be a 'modal-yield' dialog embedded in a page
	# dom = $(code)
	# if newdlog = $('div.dialog', dom)[0]
		# return $(newdlog, dom).detach()[0]
	# else if $(dom).hasClass "dialog"
		# $(dom).removeClass('modal-pending').addClass('modal')
		# return dom[0]
	doc = document.implementation.createHTMLDocument("Temp Page")
	doc.open()
	doc.write code
	doc.close()
	# We extract dialogs that are meant to be opened instead of the whole page
	if newdlog = $('div.dialog.modal-yield', doc.body)[0]
		$(newdlog).removeClass("modal-yield")
		$(newdlog).addClass("modal-pending")
		return $(newdlog, doc.body).detach()[0]

# Check whether the HTML code appropriately replaces the dialog
RP.dialog.supplant_modal = (dlog, code) ->
	if newdlog = RP.dialog.extract_modal code # $(code) # 
		RP.dialog.replace_modal newdlog, dlog
	return newdlog

# Insert a new modal dialog, possibly closing and replacing any predecessor
RP.dialog.replace_modal = (newdlog, odlog) ->
	if odlog 
		odlog.parentNode.insertBefore newdlog, odlog
		newdlog = odlog.previousSibling
		cancel_modal odlog, false
	else
		# Add the new dialog at the end of the page body if necessary
		if !newdlog.parentNode
			newdlog = document.getElementsByTagName("body")[0].appendChild newdlog
	return open_modal newdlog

# Return the dialog element for the current event target
target_modal = (event) ->
	if !event
		event = window.event
	if (odlog = $('div.dialog.modal')[0]) && $(event.currentTarget, odlog)[0]
		return odlog

open_modal = (dlog, omit_button) ->
	if (onget = $(dlog).data "onget" ) && (fcn = RP.named_function "RP."+onget.shift() )
		fcn.apply null, onget
	$(dlog).removeClass('modal-pending').removeClass('hide').addClass('modal')
	notify "load", dlog
	if !(omit_button || $('button.close', dlog)[0])
		buttoncode = '<button type=\"button\" class=\"close\" onclick=\"RP.dialog.cancel(event)\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button>'
		$('div.modal-header').prepend buttoncode
	if $(dlog).modal
		$(dlog).modal 'show'
	notify "open", dlog
	notify_injector "open", dlog
	# Set text focus as appropriate
	if (focus_sel = $(dlog).data("focus")) && (focus_elmt = $(focus_sel, dlog)[0])
		focus_elmt.focus()
	RP.dialog.arm_links()
	dlog

# Remove the dialog and notify its handler prior to removing the element
RP.dialog.close_modal = (dlog, epilog) ->
	if dlog
		if($(dlog).modal)
			$(dlog).modal 'hide'
		notify "close", dlog
		$(dlog).remove()
		notify_injector "close", dlog
	if epilog && epilog != ""
		RP.dialog.user_note epilog
	# If there's another dialog or recipe to edit waiting in the wings, trigger it
	RP.fire_triggers()
		
# Remove the dialog and notify its handler prior to removing the element
cancel_modal = (dlog, check_for_triggers=true) ->
	if($(dlog).modal)
		$(dlog).modal 'hide'
	notify "cancel", dlog
	$(dlog).remove()
	# If there's another dialog or recipe to edit waiting in the wings, trigger it
	if check_for_triggers
		RP.fire_triggers()

# Filter for submit events, ala javascript. Must return a flag for processing the event normally
filter_submit = (eventdata) ->
	context = this
	dlog = eventdata.data
	clicked = $("input[type=submit][clicked=true]")
	# return true;
	if ($(clicked).attr("value") == "Save") && (shortcircuit = notify "beforesave", dlog, eventdata.currentTarget)
		eventdata.preventDefault()
		RP.process_response shortcircuit
	else
		# Okay to submit
		# To sort out errors from subsequent dialogs, we submit the form synchronously
		#  and use the result to determine whether to do normal forms processing.
		method = $(clicked).data("method") || $('input[name=_method]', this).attr "value"
		$(context).ajaxSubmit
			url: $(clicked).data("action") || context.action,
			type: method, # $('input[name=_method]', this).attr("value"),
			async: false,
			dataType: 'json',
			error: (jqXHR, textStatus, errorThrown) ->
				jsonout = RP.post_error jqXHR, dlog # Show the error message in the dialog
				eventdata.preventDefault()
				return !RP.process_response jsonout, dlog
			success: (responseData, statusText, xhr, form) ->
				RP.post_success responseData, dlog, form
				eventdata.preventDefault()
				sorted = RP.process_response responseData, dlog
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

RP.dialog.user_note = (msg) ->
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
			RP.dialog.user_note hooks[msg_name]
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
			$("form input[type=submit]").click ->
				# Here is where we enable multiple submissions buttons with different routes
				# The form gets 'data-action', 'data-method' and 'data-operation' fields to divert
				# forms submission to a different URL and method. (data-operation declares the purpose
				# of the submit for, e.g., pre-save checks)
				$("input[type=submit]", dlog).removeAttr "clicked"
				$(this).attr "clicked", "true"
			
			# Turn a Bootstrap button group into radio buttons
			$('div.btn-group[data-toggle-name=*]').each ->
				group   = $(this);
				form    = group.parents('form').eq(0);
				name    = group.attr 'data-toggle-name'
				hidden  = $('input[name="' + name + '"]', form);
				$('button', group).each ->
					button = $(this);
					if button.val() == hidden.val()
						button.addClass 'active'
					button.live 'click', ->
						if $(this).hasClass "active"
							hidden.val $(hidden).data("toggle-default")
							$(this).removeClass "active"
						else
							hidden.val $(this).val()
							$('button', group).each ->
								$(this).removeClass "active"
							$(this).addClass "active"
		#	when "load", "onload"
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

