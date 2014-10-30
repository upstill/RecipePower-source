RP.state = RP.state || {}

jQuery ->
	# $(window).on 'window.onpopstate', RP.state.check_pop
	# window.onpopstate = RP.state.check_hash
	window.onload = RP.state.check_hash
	$(window).on 'ajax:success', RP.state.onAJAXSuccess
	if jQuery.browser.msie
		window.onhashchange = RP.state.check_hash;
		RP.state.check_hash()

getEncodedPathFromURL = (url) ->
	a = $('<a>', { href:url } )[0];
	encodeURIComponent a.pathname+a.search

RP.state.ignorePopEvent = false

# Called on page load and popstate to check if a dialog is waiting in the hashtag
RP.state.check_hash = (event) ->
	# We return when page-load triggers onpopstate (state is null) because we've already
	# checked the hash, above.
	if RP.state.ignorePopEvent # If the pop event came from setting the hashtag, don't repeat
		RP.state.ignorePopEvent = false
	else if hashtag = window.location.hash
		hashtag = decodeURIComponent hashtag
		if (match = hashtag.match(/#dialog:(.*)$/)) && (url = match[1])
			RP.submit.submit_and_process url 

RP.state.onDialogOpen = (dlog) ->
	dlog_title = dlog.title || dlog.innerText
	history.replaceState (history.state || document.title), dlog_title, window.location
	document.title = dlog_title

# If a dialog has been acquired via AJAX, modify history accordingly
RP.state.onAJAXSuccess = (event, responseData, status, xhr) ->
	if $(dlog = event.result).hasClass('dialog')
		RP.state.postDialog dlog, event.target.href, (event.target && event.target.innerText)

# Make the window title and history reflect an incoming dialog
RP.state.postDialog = (dlog, href, target_title) ->
	target_title ||= dlog.title || dlog.innerText
	window_url = window.location.pathname+window.location.search+"#dialog:"+getEncodedPathFromURL(href)
	#  if !$(event.result).hasClass 'historic'
	RP.state.ignorePopEvent = true
	history.replaceState (history.state || document.title), target_title, window_url
	document.title = target_title

# When a dialog is closed, it's either recoverable (can be backed down to) or transient (traces
# of it can be forgotten). If recoverable, we push the state without the hashtag. If transient,
# We simply remove the hashtag from the current state.
RP.state.onCloseDialog = (dlog) ->
	window_url = window.location.pathname+window.location.search  # No hashtag
	saved_title = history.state
	if $(dlog).hasClass 'historic' # A transient dialog leaves no trace on the history stack
		history.pushState null, saved_title, window_url
	else
		history.replaceState null, saved_title, window_url
	document.title = saved_title || "Collection"
