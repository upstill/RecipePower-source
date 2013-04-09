# Establish RecipePower name space and define widely-used utility functionality
window.RP = window.RP || {}

# Formerly genericHandling
# Post any errors or notifications from a JSON response
# data.error gives error message
# data.notice gives non-alarming informational message
RP.notify = (data, preface) ->
	if data.error
		RP.postError preface+data.error
	else if data.notice 
		RP.postNotice data.notice

RP.postError = (str) ->
	if str && (str.length > 0) 
		$('#container').data "errorPost", str

RP.postNotice = (str) ->
	if str && (str.length > 0)
		$('#container').data "noticePost", str
#		jNotify str, 
#			HorizontalPosition: 'center', 
#			VerticalPosition: 'top'

# Respond to the preview-recipe button by opening a popup loaded with its URL.
#   If the popup gets blocked, return true so that the recipe is opened in a new
#   window/tab.
#   In either case, notify the server of the opening so it can touch the recipe
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

# Show a beachball while an ajax request is pending
RP.ajax_loading = () ->
	if elmt = $('div.ajax-loader')[0]
		parent = elmt.parentElement
		elmt.style.width = ($(window).width()-parent.offsetLeft).toString()+"px"
		elmt.style.height = ($(window).height()-parent.offsetTop).toString()+"px"
		$(elmt).addClass "loading" 

# Remove the beachball after return
RP.ajax_loaded = () ->
	$('div.ajax-loader').removeClass "loading"

# Post a flash notification into the 'div.flash_notifications' element
flash_notification = (level, message) ->
	bootstrap_class = "alert-"+level
	html = "<div class=\"alert "+
		bootstrap_class+
		"	alert_block fade in\">
	      <button class=\"close\" data-dismiss=\"alert\">&#215;</button>"+
    message+
    "</div>"
	$('div.flash_notifications').replaceWith html
	
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
				else 
					debugger
		xmlhttp.open "GET", url, true
		xmlhttp.setRequestHeader "Accept", "text/html" 
		xmlhttp.setRequestHeader 'If-Modified-Since', ajax_options.requestHeaders['If-Modified-Since']
		xmlhttp.send()

poll_for_update = (url, ajax_options, processing_options) ->
	ajax_options.success ||= (resp, succ, xhr) ->
		if xhr.status == 204 # Use no-content status to indicate we're waiting for update
			setTimeout (-> poll_for_update url, ajax_options, processing_options), 1000
		else if xhr.status == 200
			if ajax_options.dataType == "html"
				$(processing_options.contents_selector).html xhr.responseText
			else
				# Process JSON response here
				debugger
		else
			flash_notification("error", "Sorry: got an error trying to update")
	
	ajax_options.error ||= (jqXHR, textStatus, errorThrown) ->
		# Threw an error.  We got either replacement HTML (because the controller couldn't produce JSON)
		# or a simple message string (to be placed into the notifications panel)
		dom = $(jqXHR.responseText)
		if dom.length > 0
			flash_notification "alert", "Update complete!"
			$(processing_options.contents_selector).replaceWith dom
		else
			flash_notification "alert", jqXHR.responseText
	
	jQuery.ajax url, ajax_options # setTimeout jQuery.ajax(url, ajax_options), 1000

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
	# do_request url, ajax_options, processing_options

# Linkable function to skin the get_content function. Associated link should have data values as above
RP.get_content = (url, link) ->
	jQuery.ajax "/collection/update", { type: "POST" }
	last_modified = $(link).data 'last_modified'
	get_content url, last_modified, 
		hold_msg: $(link).data('hold_msg'),
		msg_selector: $(link).data('msg_selector') || link,
		dataType: $(link).data('dataType'),
		type: $(link).data('type'),
		refresh: $(link).data('refresh'),
		contents_selector: $(link).data('contents_selector')

# Replace the page with the results of the link, properly updating the address bar
RP.get_page = (url) ->
	$('body').load url, {}, (responseText, textStatus, XMLHttpRequest) ->
		debugger;
		# RP.get_content( url, "a.update-btn" );

submit_and_process = ( request, method, assumptions ) ->
	assumptions = assumptions || {} # No assumptions if absent
	method ||= "GET"
	debugger;
	RP.modal_notify assumptions.wait_msg
	$.ajax
		type: method,
		dataType: "json",
		url: request,
		error: (jqXHR, textStatus, errorThrown) ->
			$('span.source').text jqXHR.responseText
			RP.modal_notify()
			responseData = RP.post_error jqXHR
			responseData.how = responseData.how || assumptions.how
			RP.process_response responseData
		success: (responseData, statusText, xhr) ->
			# Pass any assumptions into the response data
			RP.modal_notify()
			responseData.how = responseData.how || assumptions.how;
			RP.post_success responseData
			RP.process_response responseData

	# Handle successful return of a JSON request by running whatever success function
	#   obtains, and stashing any resulting code away for invocation after closing the
#   dialog, if any.
RP.post_success = (jsonResponse, dlog, entity) ->

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
				if newdlog = RP.dialog.extract_modal errtxt
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

# Respond to a click by optionally checking for a confirmation, firing a request at the server and appropriately handling the response
RP.submit = (request) ->
	elmt = window.event.toElement
	attribs = elmt.attributes
	if attribs.method 
		method = attribs.method.value
	else
		method = "GET"
	data = $(elmt).data();
	if confirm_msg = attribs.confirm && attribs.confirm.value
		bootbox.confirm confirm_msg, (result) ->
			if result
				submit_and_process request, method, data
	else
		submit_and_process request, method, data
	false

# Insert any notifications into 'div.notifications-panel'
RP.notify = (nots) ->
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

# Simple popup to notify the user of a process
RP.modal_notify = (msg) ->
	if msg && msg.length > 0
		bootbox.alert msg
	else
		$('div.bootbox.modal').modal 'hide'

# Process response from a request. This will be an object supplied by a JSON request,
# which may include code to be presented along with fields (how and area) telling how
# to present it. The data may also consist of only 'code' if it results from an HTML request
RP.process_response = (responseData, dlog) -> 
	# 'dlog' is the dialog currently running, if any
	# Wrapped in 'presentResponse', in the case where we're only presenting the results of the request
	dlog ||= $('div.dialog.modal')[0]
	supplanted = false
	if responseData

		# 'replacements' specifies a set of DOM elements and code to replace them
		if replacements = responseData.replacements
			i = 0;
			while i < replacements.length
				replacement = replacements[i]
				$(replacement[0]).replaceWith replacement[1]
				i++

		# 'dlog' gives a dialog DOM element to replace the extant one
		if newdlog = responseData.dlog
			RP.dialog.replace_modal newdlog, dlog
			supplanted = true

		# 'code' gives HTML code, presumably for a dialog, possibly wrapped in a page
		# If it's a page that includes a dialog, assert that, otherwise replace the page
		if (code = responseData.code) && !supplanted = RP.dialog.supplant_modal dlog, code
				responseData.page ||= code

		# 'page' gives HTML for a page to replace the current one
		if page = responseData.page
			document.open()
			document.write page
			document.close()
			supplanted = true

		# 'notifications' provides any notifications to be posted
		RP.notify responseData.notifications

		# 'done', when true, simply means close the dialog, with an optional notice
		if responseData.done && !supplanted
			RP.dialog.close_modal dlog, responseData.notice

	return supplanted;
