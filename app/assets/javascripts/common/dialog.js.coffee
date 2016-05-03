# Generic dialog management
RP.dialog = RP.dialog || {}

# Handle 'dialog-run' remote links
jQuery ->
	$('div.dialog.modal-pending').each (ix, dlog) ->
		RP.dialog.run dlog # Show any dialogs or alerts that came in with the page
	$(document).on 'shown.bs.modal', (event) ->
		# When a dialog is invoked, focus on the first autofocus item, or a string item or a text item
		RP.dialog.focus event.target
	# On hiding a modal, we wait until it's actually hidden to muck with its classes
	$(document).on 'hidden.bs.modal', (event) ->
		dlog = event.target
		$(dlog).addClass 'hide'
		# Hiding is the first step to removing, but that has to wait until the dialog has finished processing the hide
		if !$(dlog).hasClass 'keeparound'
			$(dlog).remove()
	$('.select-content', document).click (event) ->
		enclosure_selector = 'div.modal-body'
		$(enclosure_selector).hide().find('div.flash_notifications').removeClass 'flash-target'
		if targetClass = $(event.target).data 'activate'
			$(enclosure_selector+'.'+targetClass).show().find('div.flash_notifications').addClass 'flash-target'
			$('a.select-content.none').show()
			window.scrollTo 0, 0
			$(enclosure_selector).closest('div.notifs').removeClass 'collapsed'
		else
			$('a.select-content.none').hide()
			$(enclosure_selector).closest('div.notifs').addClass 'collapsed'
		event.preventDefault()

RP.dialog.focus = (dlog) ->
	($('input.autofocus', dlog)[0] || $('textarea.autofocus', dlog)[0] || $("input[type='text']", dlog)).focus()

RP.dialog.close = (event) ->
	if event
		if dlog = RP.dialog.target_modal(event)
			event.preventDefault()
		else
			return true # Do regular click-handling, presumably returning from whence we came
	else
		dlog = $('div.dialog')[0]
	close_modal dlog, "close"

###
  RP.dialog.cancel = (event) ->
      # Ask the server for any subsequent popups or a Done flag to close
      RP.submit.submit_and_process "http://local.recipepower.com:3000/popup"
  	if event
		if dlog = RP.dialog.target_modal(event)
			event.preventDefault()
		else
			return true # Do regular click-handling, presumably returning from whence we came
	else
		dlog = $('div.dialog')[0]
	# RP.dialog.close_modal dlog
	close_modal dlog, "cancel"
###

# Take over a previously-loaded dialog and run it
RP.dialog.run = (dlog) ->
	open_modal dlog, true

# Insert a new modal dialog while saving its predecessor
RP.dialog.push_modal = (newdlog, odlog) ->
	odlog ||= RP.dialog.enclosing_modal()
	newdlog = insert_modal newdlog, odlog # Insert the new dialog into the DOM
	push_modal newdlog, odlog # Hide, detach and store the parent with the child
	open_modal newdlog

# Insert a new modal dialog, closing and replacing any predecessor
RP.dialog.replace_modal = (newdlog, odlog) ->
	odlog ||= RP.dialog.enclosing_modal()
	newdlog = insert_modal newdlog, odlog
	if odlog && newdlog && (odlog != newdlog) # We might be just reopening a retained dialog
		close_modal odlog, "cancel"
	if newdlog
		open_modal newdlog
	newdlog

# Remove the dialog and notify its handler prior to removing the element
RP.dialog.close_modal = (dlog, epilog) ->
	close_modal dlog
	RP.notifications.post epilog, "popup"
	# If there's another dialog or recipe to edit waiting in the wings, trigger it
	RP.fire_triggers()

# ------------ Thus ends the public interface. Private methods: ------------------

# From a block of code (which may be a whole HTML page), extract a
# modal dialog, attach it relative to a parent dialog, and return the element
insert_modal = (newdlog, odlog) ->
	if typeof newdlog == 'string'
		# Assuming the code is a fragment for the dialog...
		dlogs = jQuery.grep $(newdlog), (elmt) ->
			$(elmt).is 'div.dialog'
		newdlog = dlogs[0]
	else
		newdlog = ($(newdlog).detach())[0]
	# Now the dialog is a detached DOM elmt: attach it relative to the parent
	if odlog && (odlog != newdlog) && odlog.parentNode # We might be just reopening a retained dialog
		odlog.parentNode.insertBefore newdlog, odlog
		newdlog = odlog.previousSibling
	# Add the new dialog at the end of the page body if necessary
	else
		newdlog = document.getElementsByTagName("body")[0].appendChild newdlog
	newdlog

# Return the dialog element for the current event target, correctly handling the event whether
# it's a jQuery event or not
RP.dialog.target_modal = (event) ->
	RP.dialog.enclosing_modal RP.event_target(event)

# Return the dialog in which the given element may be found, or any old modal if no element
RP.dialog.enclosing_modal = (elmt) ->
	dlogs = $('div.dialog.modal')
	if elmt
		for dlog in dlogs
			if $(elmt, dlog)[0]
				return dlog
		return null
	else
		return dlogs[0]

open_modal = (dlog, omit_button) ->
	if (onget = $(dlog).data "onget" ) && (fcn = RP.named_function "RP." + onget.shift() )
		fcn.apply null, onget
	RP.hide_all_empty()
	show_modal dlog
	RP.dialog.notify "load", dlog
	RP.state.onDialogOpen dlog
	if !(omit_button || $('button.close', dlog)[0])
		buttoncode = '<button type=\"button\" class=\"close dialog-x-box dialog-cancel-button\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button>'
		$('div.modal-header', dlog).prepend buttoncode
	if $(dlog).modal
		$(dlog).modal()
	if $('input:file.directUpload')[0]
		uploader_unpack()
	RP.dialog.notify "open", dlog
	notify_injector "open", dlog
	$('.token-input-field-pending', dlog).each ->
		RP.tagger.setup this
	# Arm event responders for the dialog
	if typeof RP.submit != 'undefined' # The submit module has its own onload call, so we only call for new dialogs
		RP.submit.bind dlog # Arm submission links and preload sub-dialogs
	$('.dialog-cancel-button', dlog).click (event) ->
		# When canceling, check for pending dialog/page, following instructions in the response
		close_modal RP.dialog.enclosing_modal(event.target), 'close'
		event.preventDefault()
		event.isDefaultPrevented()
	$('a.question_section', dlog).click RP.showhide
	if requires = $(dlog).data 'dialog-requires'
		for requirement in requires
			if fcn = RP.named_function "RP." + requirement + ".bind"
				fcn.apply()
	RP.fire_triggers()
	dlog

hide_modal = (dlog) ->
	if $(dlog).modal
		$(dlog).modal 'hide'
	else
		$(dlog).hide()

show_modal = (dlog) ->
	$(dlog).removeClass('hide').addClass('modal').removeClass 'modal-pending'
	if $(dlog).modal
		$(dlog).modal 'show'

# The following pair push and pop the dialog state
# 'push' detaches the parent dialog and stores it in the child's data
push_modal = (dlog, parent) ->
	hide_modal parent
	$(parent).detach()
	$(dlog).data("parent", parent)

# Remove the child dialog, notifying it of the action, and reopen the parent
# The parent was stored in the child's data
pop_modal = (dlog, action) ->
	hide_modal dlog
	if action && action != 'cancel' && parent = $(dlog).data "parent"
		insert_modal parent, dlog
		RP.dialog.notify action, dlog
		show_modal parent
	else
		RP.dialog.notify action, dlog

close_modal = (dlog, action) ->
	if dlog
		pop_modal dlog, (action || "close") # Modal can either be closed or cancelled
		RP.state.onCloseDialog dlog
		notify_injector "close", dlog

manager_of = (dlog) ->
	# Look for a manager using the dialog's class name
	if dlog
		if mgr_name = $(dlog).data 'manager'
			return RP[mgr_name]
		if classname = $(dlog).attr 'class'
			classList = classname.
			replace(/\b(modal|dialog)\b/g, ''). # Ignore 'modal', etc.
			replace(/^\s*/,'').  # Eliminate whitespace fore and aft
			replace(/\s*$/,'').
			replace(/-/g, '_'). # Translate hyphen for a legitimate function name
			split /\s+/
			for mgr_name in classList
				if RP[mgr_name]
					return RP[mgr_name]
	return null

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
RP.dialog.notify = (what, dlog) ->
	# If there's a manager module with a responder, call it
	return if !dlog
	RP.apply_hooks what, dlog # Run any messaging or functions associated with the dialog
	if (mgr = manager_of dlog) && (fcn = mgr[what] || mgr["on" + what])
		fcn dlog
	# Otherwise, run the default
	switch what
		when 'load', 'onload'
			$('[onload]', dlog).trigger 'load'
		when "open", "onopen"
		# onopen handler that sets a Boostrap dialog up to run modally: Trap the
		# form submission event to give us a chance to get JSON data and inject it into the page
		# rather than do a full page reload.
			show_modal dlog
			$(dlog).on 'shown', ->
				$('textarea', dlog).focus()
			RP.submit.form_prep dlog
	return
###
	#	when "load", "onload"
	# when "beforesave"
	# when "save", "onsave"
	# when "cancel", "oncancel"
	# when "close", "onclose"
	return
###

# Special handler for dialogs imbedded in an iframe. See 'injector.js'
notify_injector = (what, dlog) ->
	if fcn = RP.named_function what + "_dialog"
		fcn dlog

