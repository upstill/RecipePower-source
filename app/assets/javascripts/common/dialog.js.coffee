# Generic dialog management
RP.dialog = RP.dialog || {}

jQuery ->
	RP.dialog.arm_links()
	$(document).on("ajax:beforeSend", '.dialog-run', RP.dialog.beforeSend )
	$(document).on("ajax:success", '.dialog-run', RP.dialog.success )
	$(document).on("ajax:error", '.dialog-run', RP.dialog.error )

# Before making a dialog request, see if the dialog is preloaded
RP.dialog.beforeSend = (event, xhr, settings) ->
	selector = $(this).data 'selector'
	if selector && (ndlog = $(selector)[0]) # If dialog already loaded, replace the responding dialog
		RP.dialog.replace_modal event.result = ndlog, RP.dialog.target_modal(event)
		RP.state.onAJAXSuccess event
		return false;
	else
		return true;

# Success handler for fetching dialog from server
RP.dialog.success = (event, responseData, status, xhr) ->
	RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
	RP.process_response responseData, RP.dialog.target_modal(event)

RP.dialog.error = (event, jqXHR, status, error) ->
	responseData = RP.post_error jqXHR
	RP.process_response responseData, RP.dialog.target_modal(event)

# Hit the server for a dialog via JSON, and run the result
# This function can be tied to a link with only a URL to a controller for generating a dialog.
# We will get the div and run the associated dialog.
RP.dialog.get_and_go = (event, request, selector) ->
	# old_dlog is extracted from what triggered this call (if any)
	if (!event) || RP.dialog.beforeSend event
		$.ajax
			type: "GET",
			dataType: "json",
			url: request,
			error: (jqXHR, textStatus, errorThrown) ->
				RP.dialog.error event, jqXHR, textStatus, errorThrown
			success: (responseData, statusText, xhr) ->
				RP.dialog.success event, responseData, statusText, xhr

# Set up all ujs for the dialog and its requirements
RP.dialog.arm_links = (dlog) ->
	dlog ||= window.document
	$('input.cancel', dlog).click RP.dialog.cancel
	$('a.dialog-cancel-button', dlog).click RP.dialog.cancel
	$('a.question_section', dlog).click RP.showhide
	if requires = $(dlog).data 'dialog-requires'
		for requirement in requires
			if fcn = RP.named_function "RP."+requirement+".bind"
				fcn.apply()

RP.dialog.cancel = (event) ->
	if event
		if dlog = RP.dialog.target_modal(event)
			event.preventDefault()
		else
			return true # Do regular click-handling, presumably returning from whence we came
	else
		dlog = $('div.dialog')[0]
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
	if odlog && (odlog != newdlog) # We might be just reopening a retained dialog
		odlog.parentNode.insertBefore newdlog, odlog
		newdlog = odlog.previousSibling
		cancel_modal odlog, false
	else
		# Add the new dialog at the end of the page body if necessary
		if !newdlog.parentNode
			newdlog = document.getElementsByTagName("body")[0].appendChild newdlog
	return open_modal newdlog

# Return the dialog element for the current event target
RP.dialog.target_modal = (event) ->
	elmt = (event || window.event).currentTarget
	if (odlog = $('div.dialog.modal')[0]) && $(elmt, odlog)[0]
		return odlog

open_modal = (dlog, omit_button) ->
	if (onget = $(dlog).data "onget" ) && (fcn = RP.named_function "RP."+onget.shift() )
		fcn.apply null, onget
	RP.hide_all_empty()
	$(dlog).removeClass('modal-pending').removeClass('hide').addClass('modal')
	notify "load", dlog
	RP.state.onDialogOpen dlog
	if !(omit_button || $('button.close', dlog)[0])
		buttoncode = '<button type=\"button\" class=\"close\" onclick=\"RP.dialog.cancel(event)\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button>'
		$('div.modal-header').prepend buttoncode
	if $(dlog).modal
		$(dlog).modal()
	notify "open", dlog
	notify_injector "open", dlog
	$('.token-input-field-pending', dlog).each ->
		RP.tagger.setup this
	# Set text focus as appropriate
	$('[autofocus]:first').focus();
	#if (focus_sel = $(dlog).data("focus")) && (focus_elmt = $(focus_sel, dlog)[0])
	#	focus_elmt.focus()
	RP.dialog.arm_links dlog
	dlog

# Remove the dialog and notify its handler prior to removing the element
RP.dialog.close_modal = (dlog, epilog) ->
	if dlog
		if($(dlog).modal)
			$(dlog).modal 'hide'
			$('div.modal-backdrop').remove();
		notify "close", dlog
		RP.state.onCloseDialog dlog
		if $(dlog).hasClass 'keeparound'
			$(dlog).addClass('modal-pending').removeClass('modal')
		else
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
		if($(dlog).modal)
			$(dlog).modal 'hide'
		$('div.modal-backdrop').hide();
		eventdata.preventDefault()
		RP.process_response shortcircuit
	else
		# Okay to submit
		if (confirm_msg = $(clicked).data 'confirm-msg') && !confirm(confirm_msg)
			return false
		if wait_msg = $(clicked).data('wait-msg')
			RP.notifications.wait wait_msg
		# To sort out errors from subsequent dialogs, we submit the form synchronously
		#  and use the result to determine whether to do normal forms processing.
		method = $(clicked).data("method") || $('input[name=_method]', this).attr "value"
		$(context).ajaxSubmit
			url: $(clicked).data("action") || context.action,
			type: method, # $('input[name=_method]', this).attr("value"),
			async: false,
			dataType: 'json',
			error: (jqXHR, textStatus, errorThrown) ->
				RP.notifications.done()
				jsonout = RP.post_error jqXHR, dlog # Show the error message in the dialog
				eventdata.preventDefault()
				return !RP.process_response jsonout, dlog
			success: (responseData, statusText, xhr, form) ->
				RP.notifications.done()
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
		fcn dlog
	
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

