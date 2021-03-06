# Establish RecipePower name space and define widely-used utility functionality
window.RP = window.RP || {}

jQuery ->
	$('body').on "click", 'a.tablink', (event) ->
		window.open this.href,'_blank'
		RP.reporting.report this
		event.preventDefault()
	$('body').on 'click', 'a.checkbox-menu-item', (event) ->
		# The input element is either the target, or it is enclosed in the target
		# if !$(event.target).prop('tagName') == 'INPUT'
		# 	$('input', event.target).prop 'checked', !$('input', event.target).prop('checked')
		RP.submit.onClick event
		false

	# Handle popstate events by adding special parameters to the URL and submitting
	$(window).on 'popstate', (e) ->
		url = location.href
		state = e.originalEvent.state
		if (state != null)
			if state.format == 'json'
				# state.queryparams provides parametrization for making a JSON request, if possible
				RP.submit.submit_and_process RP.build_request(url, state.queryparams)
			else
				window.history.replaceState null, state.title
				window.location.assign url # Replace the page from scratch

	# Adjust the pading on the window contents to accomodate the navbar, on load and wheneer the navbar resizes
	if navbar = $('div.navbar')[0]
		$('body')[0].style.paddingTop = (navbar.offsetHeight+7).toString()+"px"
	$('div.navbar').on "resize", (event) ->
		$('body')[0].style.paddingTop = ($('div.navbar')[0].offsetHeight+7).toString()+"px"

	RP.loadElmt $('body')

# Respond to the preview-recipe button by opening a popup loaded with its URL.
#   If the popup gets blocked, return true so that the recipe is opened in a new
#   window/tab.
#   In either case, notify the server of the opening so it can touch the recipe
### Disabled until it's proven that standard remote link doesn't work
RP.servePopup = () -> 
	regexp = new RegExp "popup", "g"
	rcpid = this.getAttribute('id').replace regexp, ""
	RP.rcp_list.touch_recipe rcpid
	# Now for the main event: open the popup window if possible
	linkURL = this.getAttribute 'href'
	popUp = window.open linkURL, 'popup', 'width=600, height=300, scrollbars, resizable'
	if !popUp # || (typeof popUp === 'undefined')
		return true
	else
		popUp.focus()
		return false
###

RP.parameter_from = (name, url) ->
	url ||= window.location.href
	name = name.replace /[\[\]]/g, "\\$&"
	regex = new RegExp "[?&]" + name + "(=([^&#]*)|&|#|$)"
	results = regex.exec url
	if !results
		return null
	if !results[2]
		return ''
	decodeURIComponent results[2].replace(/\+/g, " ")

# MESSAGE RESPONDER to submit and process a URL
RP.get_and_go = (data) ->
# Parse a url to either replace a dialog or reload the page
	url = decodeURIComponent data.url
	if RP.parameter_from('mode', url) == 'modal' # It's a dialog request
		RP.submit.submit_and_process(url);
	else
		window.location = url;

# Cribbed from http://www.alistapart.com/articles/expanding-text-areas-made-elegant/
RP.makeExpandingArea = (containers) ->
	i = 0;
	while i < containers.length
		container = containers[i]
		area = $('textarea', container)[0]
		span = $('span', container)[0]
		if area.addEventListener 
			area.addEventListener 'input', () ->
				span.textContent = area.value
			, false
			span.textContent = area.value;
		else if area.attachEvent 
			# IE8 compatibility
			area.attachEvent 'onpropertychange', () ->
				span.innerText = area.value;
			span.innerText = area.value;
		i = i+1
	# Enable extra CSS
	containers.addClass 'active'

RP.event_target = (event) ->
	if event && (typeof event.target == "object")
		return event.target
	else
		return (event || window.event).currentTarget

# get the function associated with a given string, even if the string refers to elements of nested structures.
RP.named_function = (str) ->
	if(str) 
		obj = window;
		strs = str.split '.'
		i = 0; 
		while i < strs.length
			obj = obj[strs[i]]
			if((typeof obj == 'undefined') || !obj)
				break
			i = i + 1
		if(typeof obj == 'function')
			return obj
	return null;

RP.findWithin = (selector, elmt) ->
	if elmt
		$(selector, elmt)[0]
	else
		$(selector)[0]

# Find an enclosing tag of a given name
RP.findEnclosing = (tagname, elmt) ->
	elmt = elmt.parentNode
	while elmt && elmt.tagName != tagname
		elmt = elmt.parentNode
	elmt

# Find an enclosing tag of a given name TODO: redundant wrt $(elmt).closest('.'+classname) ?
RP.findEnclosingByClass = (classname, elmt) ->
	elmt = elmt.parentNode
	while elmt && !$(elmt).hasClass(classname)
		elmt = elmt.parentNode
	elmt

# Automatically open dialogs or click links that have 'trigger' class
RP.fire_triggers = (context) ->
	context ||= window.document
	$('input.trigger', context).each (ix, elmt) ->
		$(elmt).submit()
	$('a.trigger', context).each (ix, elmt) ->
		# Links with class 'trigger' get fired, either by submitting or by clicking
		if $(elmt).hasClass 'submit'
			# Let the submit module handle submit links
			RP.submit.fire elmt
		else
			$(elmt).trigger "click"
	$('div.trigger.dialog', context).each (ix, elmt) ->
		# Dialogs with class 'trigger' get autorun
		$(elmt).removeClass "trigger"
		RP.dialog.run elmt

# For the FAQ page: click on a question to show the associated answer
RP.showhide = (event) ->
	associated = event.currentTarget.parentNode.nextSibling
	show_sib = $(associated).hasClass "hide"
	$('div.answer').hide 200
	$('div.answer').addClass "hide"
	if show_sib
		$(associated).show 300
		$(associated).removeClass "hide"
	event.preventDefault()
	
# Use a vanilla httprequest to ping the server, bypassing jQuery
do_request = (url, ajax_options, processing_options) ->
	# Send the request using minimal Javascript
	if window.XMLHttpRequest
		xmlhttp=new XMLHttpRequest()
	else
		try
			xmlhttp = new ActiveXObject "Msxml2.XMLHTTP"
		catch e 
			try 
				xmlhttp = new ActiveXObject("Microsoft.XMLHTTP")
			catch e
				xmlhttp = null
	if xmlhttp != null
		xmlhttp.onreadystatechange = () ->
			if xmlhttp.readyState==4
				if xmlhttp.status==200
					# Now we have code, possibly required for jQuery and certainly 
					# required for any of our javascript. Ensure the code is loaded.
					$(processing_options.contents_selector).inner_html = xmlhttp.responseText
		xmlhttp.open "GET", url, true
		xmlhttp.setRequestHeader "Accept", "text/html" 
		xmlhttp.setRequestHeader 'If-Modified-Since', ajax_options.requestHeaders['If-Modified-Since']
		xmlhttp.send()

# Handle successful return of a JSON request by running whatever success function
#   obtains, and stashing any resulting code away for invocation after closing the
#   dialog, if any.
RP.post_success = (jsonResponse, dlog, entity) ->

	# Call processor function named in the response
	if closer = RP.named_function jsonResponse.processorFcn
		closer jsonResponse

	# Call the dialog's response function
	if(dlog != undefined) || (entity != undefined)
		RP.notify 'save', (entity || dlog)

	# Stash the result for later processing
	# if dlog != undefined
	#	dialogResult dlog, jsonResponse
	return false

# Handle the error result from either a forms submission or a request of the server
#  by treating the html as code to be rendered and sticking it in an object attached
#  to the dialog, if any.
RP.post_error = ( jqXHR, dlog ) ->
	# Any error page we get we will <try> to present modally
	parsage = {}
	if errtxt = jqXHR.responseText 
		# See if it's valid JSON, b/c you never know...
		try
			parsage = JSON && JSON.parse(errtxt) || $.parseJSON(errtxt)
		catch e
			# Not valid JSON. Maybe it's a page to go to?
			if errtxt.match /^\s*<!DOCTYPE html>/ 
				parsage =
					page: errtxt
			else if errtxt.match /^\s*<div/ # Detect a dialog
				parsage =
					code: errtxt
			else if errtxt.match /^\s*<form/ # Detect a form replacement
				wrapper = document.createElement('div');
				wrapper.innerHTML = errtxt;
				formnode = wrapper.firstChild
				parsage = 
					form: formnode;
				wrapper.removeChild formnode 
			else
				# Okay. Assume it's just a string error report
				parsage = 
					errortext: errtxt.substring 0,250
	if errors = parsage.errors
		clicked = $("input[type=submit][clicked=true]")
		form = $(clicked).parents('form:first')
		if baseErrorDiv = $('div.alert', form)[0]
			if errors.base
				for node in baseErrorDiv.childNodes
					if (node.nodeType == 3)
						node.nodeValue = errors.base
				$(baseErrorDiv).show()
			else
				$(baseErrorDiv).hide()
	result = null
	# Stash the result in the dialog, if any
	# if dlog != 'undefined'
	# dialogResult dlog, parsage
	return parsage;
	
# Safely detach a node from its parent
RP.detach = (node) ->
	parent = node.parentNode;
	parent.removeChild(node);

# Respond to the change of a popup (say) by submtting a request. Both
# request and its data are encoded in the element's data; the value is added to the request here
RP.change = (event) ->
	elmt = event.target
	data = $(elmt).data()
	query = data.querydata
	# Stick the value of the element into the named parameter ('value' default)
	if data.valueparam
		query[data.valueparam] = elmt.value
	else
		query.value = elmt.value
	# Fire off an Ajax call notifying the server of the (re)classification
	RP.submit.submit_and_process RP.build_request(data.request, query), elmt

# Crack the query string (if any) to produce an object
parse_query = (query) ->
	rtnval = {}
	if query
		pl     = /\+/g  # Regex for replacing addition symbol with a space
		search = /([^&=]+)=?([^&]*)/g
		decode = (s) ->
			decodeURIComponent s.replace(pl, " ")
		while (match = search.exec(query))
			rtnval[decode match[1]] = decode match[2]
	rtnval

# Rebuild a request string using values from the object 'assert'
RP.build_request = (request, assert) ->
	if assert
		path = request.replace /\?.*/, ''
		query = parse_query request.replace(path,'').replace("?", '')
		# replace values in the existing query according to the imposed query
		for attrname,attrvalue of assert
			query[attrname] = attrvalue
		str = []
		for attrname,attrvalue of query
			str.push(encodeURIComponent(attrname) + "=" + encodeURIComponent(attrvalue));
		if str.length > 0
			path += "?" + str.join("&")
		path
	else
		request

# Ensure that a newly-loaded element is properly attended to
RP.loadElmt = (elmt) ->
	$(elmt).trigger 'load'
	$('[onload]', elmt).trigger 'load'
	for toSetup in $('[data-setup]', elmt)
		if fcn = RP.named_function $(toSetup).data "setup"
			fcn toSetup
	RP.fire_triggers elmt # For unobtrusive triggers

RP.onload = (event) ->
	x=2

# Process response from a request. This will be an object supplied by a JSON request,
# which may include code to be presented along with fields (how and area) telling how
# to present it. The data may also consist of only 'code' if it results from an HTML request
RP.process_response = (responseData, odlog) ->
	# 'odlog' is the dialog currently running, if any
	# Wrapped in 'presentResponse', in the case where we're only presenting the results of the request
	odlog ||= RP.dialog.enclosing_modal() # Hopefully there's only one currently-active dialog
	supplanted = false
	if responseData

		# Handle any notifications in the response
		RP.notifications.from_response responseData

		# 'replacements' specifies a set of DOM elements and code to replace them
		if replacements = responseData.replacements
			for replacement in replacements
				elmt = $(replacement[0])[0]
				if replacement[1]
					if newElmt = $(replacement[1])
						RP.replaceElmt elmt, newElmt
						if $(newElmt).hasClass 'pagelet-body'
							window.scrollTo 0, 0
				else
					RP.removeElmt elmt
				# The third value may be a function name to call on the replaced elemnnt
				if (loader = replacement[2]) && (loadFcn = RP.named_function(loader))
					loadFcn($(replacement[0])[0])

		if insertions = responseData.insertions # [ item_selector, item_data, composite_selector
			for insertion in insertions
				if elmt = $(insertion[0])[0]
					RP.removeElmt elmt
				newElmt = $(insertion[1])[0]
				RP.prependElmt newElmt, insertion[2]

		if redirect = responseData.redirect
			window.location.assign redirect # "http://local.recipepower.com:3000/collection" #  href = href

		if followup = responseData.followup # Submit a follow-up request
			# The idea here is the followup is to replace a certain element, IF IT ALREADY EXISTS. Thus, to
			# delete an item from its home page, we need to go elsewhere, but if we're NOT on the item's page,
			# life continues as normal.
			if !followup.target || $(followup.target)[0] # Either there is no target, or the target exists
				RP.submit.submit_and_process followup.request

		if responseData.reload
			location.reload()

		# Remember this URL for getting back to here
		if state = responseData.pushState
			if window.history.state == null # If we're leaving an original page, define a state vbl. so we can reload
				window.history.replaceState { title: document.title }, document.title
			state_with_title = state[0]
			state_with_title.title = RP.state.title state[1]
			window.history.pushState state_with_title, state_with_title.title, state[2]
			document.title = state_with_title.title

		if deletions = responseData.deletions
			for deletion in deletions
				item = $(deletion)[0]
				if $(item).hasClass('masonry-item') && $(item.parentNode).hasClass 'js-masonry'
					$(item.parentNode).masonry 'remove', item
					$(item.parentNode).masonry 'layout'
				else
					$(deletion).remove()

		# 'odlog' gives a dialog DOM element to replace the extant one
		if newdlog = responseData.dlog
			RP.dialog.replace_modal newdlog, odlog
			supplanted = true

		# 'odlog' gives a dialog DOM element to replace the extant one, with the option of restoring the latter later
		if newdlog = responseData.push
			RP.dialog.push_modal newdlog, odlog
			supplanted = true

		# 'code' gives HTML code, presumably for a dialog, possibly wrapped in a page
		# If it's a page that includes a dialog, assert that, otherwise replace the page
		if (code = responseData.code) && !supplanted = RP.dialog.replace_modal code, odlog
				responseData.page ||= code

		if form = responseData.form
			# Find the form to replace in error scenarios
			action = form.getAttribute("action")
			if replaced = $("form[action=\'"+action+"\']")[0]
				replaced.parentNode.replaceChild(form, replaced);
		
		# 'page' gives HTML for a page to replace the current one
		if page = responseData.page
			document.open()
			document.write page
			document.close()
			supplanted = true

		# 'done', when true, simply means close the dialog, with an optional notice
		if !supplanted
			if responseData.done
				RP.dialog.close_modal odlog, responseData.notice
			# else if responseData.replacements && odlog
			# 	RP.dialog.run odlog

	return supplanted

RP.replaceElmt = (oldElmt, newElmt) ->
	if RP.hasOwnProperty('masonry') && RP.masonry.replaceItem(oldElmt, newElmt)
		RP.loadElmt newElmt
	else
		RP.loadElmt $(newElmt).replaceAll($(oldElmt))

RP.removeElmt = (elmt) ->
	RP.masonry.removeItem(elmt) || $(elmt).remove()

# Prepend the element at the top of the list given by 'selector' (which can be a parent node)
RP.prependElmt = (elmt, parent) ->
	if !RP.masonry.prependItem(elmt, parent)
		$(parent).prepend elmt
	RP.loadElmt elmt

RP.appendElmt = (item, parent) ->
	if !RP.masonry.appendItem item, parent
		$(parent).append item

RP.notify = (what, entity) ->
	# If the entity or the dialog have hooks declared, use them
	if dlog = $(entity).closest('div.dialog')[0]
		RP.dialog.notify what, dlog
	else
		RP.apply_hooks what, entity

RP.apply_hooks = (what, entity) ->
	fcn_name = what + "Fcn";
	msg_name = what + "Msg";
	if hooks = $(entity).data "hooks"
		if hooks.hasOwnProperty msg_name
			RP.notifications.post hooks[msg_name], "popup"
		if hooks.hasOwnProperty fcn_name
			fcn = RP.named_function hooks[fcn_name]
			return fcn entity # We want an error if the function doesn't exist
