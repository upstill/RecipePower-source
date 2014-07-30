# Establish RecipePower name space and define widely-used utility functionality
window.RP = window.RP || {}

jQuery ->
	$('body').on "click", 'a.tablink', (event) ->
		window.open this.href,'_blank'
		event.preventDefault()

	# Adjust the pading on the window contents to accomodate the navbar, on load and wheneer the navbar resizes
	if navbar = $('div.navbar')[0]
		$('body')[0].style.paddingTop = (navbar.offsetHeight+7).toString()+"px"
	$('div.navbar').on "resize", (event) ->
		$('body')[0].style.paddingTop = ($('div.navbar')[0].offsetHeight+7).toString()+"px"

	RP.fire_triggers()

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

###
# Add a bookmark for the current page
RP.bm = (title, addr) ->
	if window.sidebar # Mozilla Firefox Bookmark
		window.sidebar.addPanel location.href, document.title, ""
	else if false # IE Favorite
		window.external.AddFavorite location.href, document.title 
	else if window.opera && window.print # Opera Hotlist
		this.title = document.title;
		return true;
	else # webkit - safari/chrome
		alert 'Press ' + ((navigator.userAgent.toLowerCase().indexOf('mac') != - 1) ? 'Command/Cmd' : 'CTRL') + ' + D to bookmark this page.'

# Go to a page and push a special state
RP.getgo = (request, addr) ->
	$.ajax
		type: "GET",
		dataType: "html",
		url: request,
		error: (jqXHR, textStatus, errorThrown) ->
			debugger
		success: (response, statusText, xhr) ->
			# Pass any assumptions into the response data
			document.getElementsByTagName("html")[0].innerHTML = response;
			document.title = "Cookmark";
			window.history.pushState
				html: response,
				pageTitle: "Cookmark"
			,"Cookmark", addr
###

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

# Automatically open dialogs or click links that have 'trigger' class
RP.fire_triggers = ->
	$('div.dialog.trigger').removeClass("trigger").each (ix, dlog) ->
		RP.dialog.run dlog
	$("a.trigger").removeClass("trigger").trigger "click"
	$('a.preload').trigger "preload"

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


# Replace the page with the results of the link, properly updating the address bar
RP.get_page = (url) ->
	$('body').load url, {}, (responseText, textStatus, XMLHttpRequest) ->
		$('body').trigger('load')
		window.history.replaceState { an: "object" }, 'Collection', url

# Parse a url to either replace a dialog or reload the page
RP.get_and_go = (data) ->
	url = decodeURIComponent data.url
	if url.match /modal=/
		RP.dialog.get_and_go null, url
	else
		window.location = url # RP.get_page data.url

# Handle successful return of a JSON request by running whatever success function
#   obtains, and stashing any resulting code away for invocation after closing the
#   dialog, if any.
RP.post_success = (jsonResponse, dlog, entity) ->

	# Call processor function named in the response
	if closer = RP.named_function jsonResponse.processorFcn
		closer jsonResponse

	# Call the dialog's response function
	if(dlog != undefined) || (entity != undefined)
		RP.dialog.onsave dlog, entity

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
					errortext: errtxt
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
	RP.submit.submit_and_process RP.build_request(data.request, query), "GET", data

# Build a request string from a structure with attributes 'request' and 'querydata'
RP.build_request = (request, query) ->
	# Encode the querydata into the request string
	str = []
	for attrname,attrvalue of query
		str.push(encodeURIComponent(attrname) + "=" + encodeURIComponent(attrvalue));
	# Fire off an Ajax call notifying the server of the (re)classification
	data.request+"?"+str.join("&")

# Process response from a request. This will be an object supplied by a JSON request,
# which may include code to be presented along with fields (how and area) telling how
# to present it. The data may also consist of only 'code' if it results from an HTML request
RP.process_response = (responseData, dlog) -> 
	# 'dlog' is the dialog currently running, if any
	# Wrapped in 'presentResponse', in the case where we're only presenting the results of the request
	dlog ||= $('div.modal')[0]
	supplanted = false
	if responseData

		# 'replacements' specifies a set of DOM elements and code to replace them
		if replacements = responseData.replacements
			for replacement in replacements
				$(replacement[0]).replaceWith replacement[1]
				$(replacement[0]).trigger "load"
				# The third value may be a function name to call on the replaced elemnnt
				if (loader = replacement[2]) && (loadFcn = RP.named_function(loader))
					loadFcn($(replacement[0])[0])


    ###
		if streams = responseData.streams
			for stream in streams
				if !stream[1].append
					$(stream[0]).empty()
				RP.stream.fire stream[1].kind, stream[1].append
    ###

		if redirect = responseData.redirect
			window.location.assign redirect # "http://local.recipepower.com:3000/collection" #  href = href

		if state = responseData.pushState
			window.history.pushState null, state[1], state[0]

		if deletions = responseData.deletions
			for deletion in deletions
				$(deletion).remove()

		# 'dlog' gives a dialog DOM element to replace the extant one
		if newdlog = responseData.dlog
			RP.dialog.replace_modal newdlog, dlog
			supplanted = true

		# 'code' gives HTML code, presumably for a dialog, possibly wrapped in a page
		# If it's a page that includes a dialog, assert that, otherwise replace the page
		if (code = responseData.code) && !supplanted = RP.dialog.replace_modal code, dlog
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
				RP.dialog.close_modal dlog, responseData.notice
			else if responseData.replacements && dlog
				RP.dialog.run dlog

		# Handle any notifications in the response
		RP.notifications.from_response responseData

	return supplanted
