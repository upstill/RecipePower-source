RP.state = RP.state || {}

jQuery ->
	# $(window).on 'window.onpopstate', RP.state.check_pop
	window.onpopstate = RP.state.check_hash
	$(window).on 'ajax:success', RP.state.onOpenDialog

getPathFromURL = (url) ->
	a = $('<a>', { href:url } )[0];
	a.pathname+a.search

# Called on page load to check if a dialog is waiting in the hashtag
RP.state.check_hash = ->
	if hashtag = window.location.hash
		if (match = hashtag.match(/#dialog:(.*)$/)) && (url = match[1])
			url = decodeURIComponent url
			RP.dialog.get_and_go null, url
	else # No hashtag: make sure there's no dialog
		if (dlog = $('div.dialog')[0]) && $(dlog).modal
			RP.dialog.close_modal dlog

# When a dialog is opened via AJAX, we push the state including the request hashtag
RP.state.onOpenDialog = (event) ->
	target_path = getPathFromURL event.target.href
	history.pushState null, event.result.title, window.location.pathname+"#dialog:"+target_path
	document.title = event.result.title

# When a dialog is closed, it's either recoverable (can be backed down to) or transient (traces
# of it can be forgotten). If recoverable, we push the state without the hashtag. If transient,
# We simply remove the hashtag from the current state.
RP.state.onCloseDialog = (dlog) ->
	history.pushState null, window.document.title, window.location.pathname
	document.title = window.document.title
