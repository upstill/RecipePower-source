RP.state = RP.state || {}

jQuery ->
	# $(window).on 'window.onpopstate', RP.state.check_pop
	window.onpopstate = RP.state.check_hash
	$(window).on 'ajax:success', RP.state.onAJAXSuccess
	if jQuery.browser.msie
		window.onhashchange = RP.state.check_hash;
		RP.state.check_hash()

getEncodedPathFromURL = (url) ->
	a = $('<a>', { href:url } )[0];
	encodeURIComponent a.pathname+a.search

# Called on page load and popstate to check if a dialog is waiting in the hashtag
RP.state.check_hash = (event) ->
	# We return when page-load triggers onpopstate (state is null) because we've already
	# checked the hash, above.
	if hashtag = window.location.hash
		if (match = hashtag.match(/#dialog:(.*)$/)) && (url = match[1])
			url = decodeURIComponent url
			RP.dialog.get_and_go null, url
	else # No hashtag: make sure there's no dialog
		if (dlog = $('div.dialog')[0]) && $(dlog).modal
			RP.dialog.close_modal dlog

# If a dialog has been acquired via AJAX, modify history accordingly
RP.state.onAJAXSuccess = (event, responseData, status, xhr) ->
	if $(dlog = event.result).hasClass('dialog')
		target_title = (event.target && event.target.innerText) || dlog.title || dlog.innerText
		window_url = window.location.pathname+window.location.search+"#dialog:"+getEncodedPathFromURL(event.target.href)
		if !$(event.result).hasClass 'historic'
			history.replaceState document.title, target_title, window_url
		# else
		#	history.pushState null, target_title, window_url
		# document.title = target_title

# When a dialog is closed, it's either recoverable (can be backed down to) or transient (traces
# of it can be forgotten). If recoverable, we push the state without the hashtag. If transient,
# We simply remove the hashtag from the current state.
RP.state.onCloseDialog = (dlog) ->
	window_url = window.location.pathname+window.location.search  # No hashtag
	if $(dlog).hasClass 'historic' # A transient dialog leaves no trace on the history stack
		history.pushState null, window.document.title, window_url
	else
		history.replaceState null, window.document.title, window_url
	document.title = window.document.title
