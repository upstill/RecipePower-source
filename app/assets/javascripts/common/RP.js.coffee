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
	
poll_for_update = (ajax_options, last_modified, processing_options) ->
	ajax_options.success ||= (resp, succ, xhr) ->
		debugger
		if xhr.status == 304
			poll_for_update ajax_options, last_modified, processing_options
		else if xhr.status == 200
			if ajax_options.dataType == "html"
				$(processing_options.contents_selector).innerHTML = xhr.responseText
			else
				# Process response structure here
				debugger
		else
			debugger
			$(processing_options.link).innerHTML = 'error'

	ajax_options.error ||= (jqXHR, textStatus, errorThrown) ->
		debugger
		$('.notifications-panel').html jqXHR.responseText

	if ajax_options.requestHeaders
		ajax_options.requestHeaders['If-Modified-Since'] = last_modified
	else
		ajax_options.requestHeaders = { 'If-Modified-Since': last_modified }

	ajax_options.requestHeaders['X-CSRF-Token'] ||= $('meta[name="csrf-token"]').attr 'content'

	setTimeout jQuery.ajax(ajax_options), 1000

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
	hold_msg = options.hold_msg || "Updating..."
	msg_selector = options.msg_selector || "#notifications-panel"
	
	ajax_options = 
		url: url,
		dataType: options.dataType || "json",
		type: options.type || "get",
	ajax_options.data = "refresh=true" if options.refresh
	
	processing_options = 
		contents_selector: options.contents_selector || "div.collection"
		
	# Notify the user of the ongoing process by replacing the message selector with a bootstrap notification
	$(msg_selector).replaceWith "<span>"+hold_msg+"</span>"
	
	poll_for_update ajax_options, last_modified, processing_options

# Linkable function to skin the get_content function. Associated link should have data values as above
RP.get_content = (url, link) ->
	last_modified = $(link).data 'last_modified'
	get_content url, last_modified, 
		hold_msg: $(link).data('hold_msg'),
		msg_selector: $(link).data('msg_selector') || link,
		dataType: $(link).data('dataType'),
		type: $(link).data('type'),
		refresh: $(link).data('refresh'),
		contents_selector: $(link).data('contents_selector')

		
		
