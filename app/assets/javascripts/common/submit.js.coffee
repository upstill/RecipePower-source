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
	# Set up processing for click events on links with a 'submit' class
	$(document).on "click", 'a.submit', RP.submit.onClick
	$(document).on "ajax:beforeSend", 'form.ujs-submit', RP.submit.beforeSend
	$(document).on "ajax:success", 'form.ujs-submit', RP.submit.success
	$(document).on "ajax:error", 'form.ujs-submit', RP.submit.error
	$(document).bind "ajaxComplete", (event) ->
		RP.submit.dequeue() # Check for queued-up requests
	# -- handle JSON responses properly,
	# -- short-circuit redundant forms requests
	# -- provide for keep-alive, popup and confirmation interaction
	# -- deal with errors
	$(document).on "submit", 'form.submit', (event) ->
		RP.submit.submit_and_process $(this).attr('action'), this
		false
	# Handle click/dbl-click/opt-click on an 'onlinks' div item
	# It expects two following links:
	# -- one with a target '_blank' to be launched on single-click
	# -- one with class 'submit' which will get launched on double-click/opt-click
	$(document).on 'click', 'div.onlinks', (event) ->
		elmt = event.currentTarget
		timer = null
		if $(elmt).hasClass('clicked') || event.altKey
			clearTimeout timer    # prevent single-click action
			console.log 'Double-click'
			if dblcl = $('a.dblclicker', elmt)[0]
				$(dblcl).click()
			$(elmt).removeClass 'clicked'
		else
			timer = setTimeout ->
				if $(elmt).hasClass 'clicked'
					console.log 'Click'
					if cl = $('a.clicker', elmt)[0]
						$(cl).click()
					$(elmt).removeClass 'clicked'
			, 300
			$(elmt).addClass 'clicked'
		event.preventDefault()
	$(document).on 'click', 'a[target="_blank"]', (event) ->
		elmt = event.currentTarget
		RP.reporting.report elmt
		win = window.open elmt.href, '_blank'
		win.focus();
		false

# Make a request from an element, but only if one is not already loading
RP.submit.enqueue = (request, elmt) ->
	if $('.loading')[0] # Only one request at a time please
		$(elmt).data 'href', request # Save for later
		$(elmt).addClass 'queued'
	else if typeof(request) == 'function'
		request elmt
	else
		RP.submit.submit_and_process request, elmt

RP.submit.dequeue = ->
	if next = $('.queued')[0]
		$(next).removeClass 'queued'
		RP.submit.fire next

RP.submit.block_on = (elmt) ->
	$(elmt).addClass 'loading'

RP.submit.block_off = (elmt) ->
	$(elmt).removeClass 'loading'

RP.submit.blocking_on = (elmt) ->
	$(elmt).hasClass 'loading'

# Master function for submitting AJAX, perhaps in the context of a DOM element that triggered it
# Elements may fire off requests by:
# -- being clicked (click events get here by association with the 'submit' class
# -- having a 'preload' class, which attaches the result of the request to the element pending a subsequent click
RP.submit.submit_and_process = ( request, elmt ) ->
	$(elmt).addClass 'trigger'
	unless elmt && (RP.submit.blocking_on(elmt) || (preloaded = shortCircuit elmt))
		RP.submit.block_on elmt
		ajdata =
			dataType: "json",
			# contentType: "application/json",
			url: request,
			error: (jqXHR, statusText, errorThrown) ->
				# TODO Not actually posting an error for the user
				responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
				RP.submit.handleResponse elmt, responseData, statusText, errorThrown
			success: (responseData, statusText, xhr) ->
				RP.submit.handleResponse elmt, responseData, statusText, xhr
		if $(elmt).prop("tagName") == "FORM"
			ajdata.url ||= $(elmt).attr('action')
			method = $(elmt).attr('method')
			ajdata.data = $(elmt).serialize()
		else
			method = $(elmt).data('method')
		if method
			ajdata.type = method
		$.ajax ajdata
	if preloaded
		# The preloaded data is either a DOM element for a dialog, a source string for the dialog, or a responseData structure
		if preloaded.done || preloaded.dlog || preloaded.code || preloaded.replacements
			RP.submit.handleResponse elmt, preloaded
		else if typeof(ndlog = preloaded) == "string" || (ndlog = $(preloaded)[0]) # Got a string or a DOM element => run dialog
			$(elmt).removeClass 'trigger'
			RP.dialog.push_modal ndlog, RP.dialog.enclosing_modal(elmt)

RP.submit.form_onload = (event) ->
	RP.submit.form_prep event.target

RP.submit.open_or_launch = (event) ->
	elmt = event.target
	timer = null
	if $(elmt).hasClass('clicked') || event.altKey
		clearTimeout timer    # prevent single-click action
		if sib = $(elmt).siblings('a.submit')[0]
			RP.submit.fire sib
		$(elmt).removeClass 'clicked'
	else
		timer = setTimeout ->
			if $(elmt).hasClass 'clicked'
				if (sib = $(elmt).siblings('a[target="_blank"]'))[0]
					sib.click()
				$(elmt).removeClass 'clicked'
		, 700
		$(elmt).addClass 'clicked'
	event.preventDefault()

# Make a form ready for our special handling
RP.submit.form_prep = (context) ->
	context ||= document
	# Turn a Bootstrap button group into radio buttons
	$("input[type=submit]", context).click ->
		# Here is where we enable multiple submissions buttons with different routes
		# The form gets 'data-action', 'data-method' and 'data-operation' fields to divert
		# forms submission to a different URL and method. (data-operation declares the purpose
		# of the submit for, e.g., pre-save checks)
		form = $(this).closest('form')
		$("input[type=submit]", form).removeAttr "clicked"
		$(this).attr "clicked", "true"
	$('div.btn-group', context).each ->
		group = $(this);
		if name = group.attr 'data-toggle-name'
			form = group.parents('form').eq(0);
			hidden = $('input[name="' + name + '"]', form);
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

# Filter for submit events, ala javascript. Must return a flag for processing the event normally
RP.submit.filter_submit = (eventdata) ->
	context = this
	dlog = $(this).closest('div.dialog')[0] # enclosing dialog, if any
	clicked = $("input[type=submit][clicked=true]")
	# return true;
	if ($(clicked).attr("value") == "Save") && (shortcircuit = RP.notify "beforesave", eventdata.currentTarget)
		close_modal dlog, "cancel"
		eventdata.preventDefault()
		RP.process_response shortcircuit
	else
		# Okay to submit
		if !proceedWithConfirmation clicked
			return false
		if wait_msg = $(clicked).data('waitMsg')
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

# preload ensures that the results of the query are available
preload = (elmt) ->
	if RP.submit.blocking_on elmt
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
	if href = $(elmt).data('href') || (elmt.attributes.href && elmt.attributes.href.value)
		RP.submit.block_on elmt
		$.ajax
			type: "GET",
			dataType: "json",
			contentType: "application/json",
			url: href,
			error: (jqXHR, statusText, errorThrown) ->
				responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
				RP.submit.handleResponse elmt, responseData, statusText, errorThrown
			success: (responseData, statusText, xhr) ->
				RP.submit.handleResponse elmt, responseData, statusText, xhr

# Handle submission links
RP.submit.bind = (dlog) ->
	dlog ||= $('body') # window.document
	$('.preload', dlog).each (ix, elmt) ->
		preload elmt
	$('.trigger', dlog).each (ix, elmt) ->
		RP.submit.fire elmt

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

RP.submit.enclosing_form = (elmt) ->
	$(elmt || this).closest('form').submit()

RP.submit.why = (event) ->
	false

# Respond to a click on a '.submit' element by optionally checking for a confirmation, firing a request at the server and appropriately handling the response
RP.submit.onClick = (event) ->
	# We can enclose an <input> element (like a checkbox) in a link that handles the actual click
	try
		RP.submit.fire event.currentTarget
	catch err # Must ensure we return false to prevent handling by others
	  console.log "Click handling on submit link barfed: "+err
	false

RP.submit.fire = (elmt) ->
	if RP.submit.blocking_on elmt # This may already be loading
		handleEnclosingNavTab elmt
		$(elmt).addClass('trigger') # Mark for immediate opening
	else if proceedWithConfirmation(elmt)
		# If the submission is made from a top-level menu, make the menu active
		handleEnclosingNavTab elmt
		if href = $(elmt).data('href') || (elmt.attributes.href && elmt.attributes.href.value) || (elmt.tagName == 'FORM' && elmt.action)
			RP.submit.enqueue href, elmt

handleEnclosingNavTab = (menuElmt) ->
	if !$(menuElmt).hasClass "transient" # So marked if its selection will not affect what menu element is active
		while menuElmt && !$(menuElmt).hasClass "master-navtab"
			menuElmt = RP.findEnclosing "LI", menuElmt
		if menuElmt # Select this menu element exclusively
			$('.master-navtab').removeClass "active"
			# $('.master-navtab a').css 'color','#999'
			$(menuElmt).addClass "active"
			# $('>a', menuElmt).css 'color','white'

proceedWithConfirmation = (elmt) ->
	if confirm_msg = $(elmt).data('confirmMsg') || $('input[type="submit"]', elmt).data 'confirmMsg'
		confirm confirm_msg
	else
		true

postWaitMsg = (elmt) ->
	if msg = $(elmt).data 'waitMsg'
		RP.notifications.wait msg

shortCircuit = (elmt) ->
	data = (elmt && $(elmt).data()) || {}
	postWaitMsg elmt
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
RP.submit.handleResponse = (elmt, responseData, status, xhr) ->
	RP.notifications.done()
	# A response has come in, so the element is no longer loading
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
	RP.submit.block_off elmt

# Before making a form submission, see if the dialog is preloaded
RP.submit.beforeSend = (event, xhr, settings) ->
	elmt = event.currentTarget
	# If the submission is made from a top-level menu, make the menu active
	if proceedWithConfirmation elmt
		postWaitMsg elmt
		true

# Success handler for fetching dialog from server
RP.submit.success = (event, responseData, statusText, xhr) ->
	RP.notifications.done()
	if typeof(responseData) == 'string'
		responseData = JSON && JSON.parse(responseData) || $.parseJSON(responseData)
	RP.post_success responseData # Don't activate any response functions since we're just opening the dialog
	RP.process_response responseData, RP.dialog.enclosing_modal(event.currentTarget)

RP.submit.error = (event, jqXHR, statusText, errorThrown) ->
	# TODO Not actually posting an error for the user
	RP.notifications.done()
	if responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
		RP.process_response responseData, RP.dialog.enclosing_modal(event.currentTarget)