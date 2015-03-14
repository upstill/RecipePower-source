RP.stream ||= {}

jQuery ->
	$(window).scroll () ->
		RP.stream.check()
	RP.stream.check()

RP.stream.onload = (event) ->
	RP.stream.check event.target

RP.stream.check = (elmt) ->
	if $(elmt).hasClass('stream-trigger') || elmt = $('a.stream-trigger')[0]
		rect = elmt.getBoundingClientRect()
		if rect && (rect.bottom-rect.height) <= $(window).height()
			RP.stream.fire elmt

# Event-driven interface, an onload handler
RP.stream.go = (evt) ->
	RP.stream.fire evt.target

RP.stream.fire = (elmt) ->
	querypath = $(elmt).data('path')
	parent = RP.findEnclosingByClass 'stream-items-parent', elmt
	$('.beachball', parent).removeClass "hide"
	$(elmt).remove() # Remove the link element to forestall subsequent loads
	# It will be replaced when the trigger div gets replaced, IFF there's more material to come
	source = new EventSource querypath
	source.onerror = (evt) ->
		source.close()
		state = evt.target.readyState
	source.addEventListener 'end_of_stream', (e) ->
		jdata = JSON.parse e.data
		source.close()
		RP.process_response jdata
		RP.stream.check() # If the stream link is visible, go for more
	source.addEventListener 'stream_item', (e) ->
		jdata = JSON.parse e.data
		# If the item specifies a handler, call that
		if handler = jdata.handler && fcn = RP.named_function
			fcn.apply jdata
		else if jdata.elmt
			# Standard handling: convert text to HTML and append to list
			RP.appendElmt($(jdata.elmt), parent)
		else
			RP.process_response jdata

RP.stream.buffer_test = ->
	source = new EventSource('/stream/buffer_test')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		jdata = JSON.parse e.data
		$('#seeker_results').append("<div>"+jdata.text+"</div>")
