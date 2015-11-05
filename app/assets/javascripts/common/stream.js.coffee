RP.stream ||= {}

jQuery ->
	$(window).scroll () ->
		$('.stream-items-parent .stream-trigger').each (index) ->
			RP.stream.check this

RP.stream.onload = (event) ->
	RP.stream.check event.target

RP.stream.check = (elmt) ->
	# We can be called with the trigger-item's parent or any child thereof
	if !$(elmt).hasClass 'stream-trigger'
		parent = elmt
		if !$(parent).hasClass 'stream-items-parent'
			parent = RP.findEnclosingByClass parent, 'stream-items-parent'
		elmt = $('.stream-trigger', parent)[0]
	if (trigger_check_name = $(elmt).data('trigger-check')) && (trigger_check_fcn = RP.named_function trigger_check_name)
		trigger_check_fcn elmt
	else
		rect = elmt.getBoundingClientRect()
		if rect && (rect.bottom-rect.height) <= $(window).height()
			RP.stream.fire elmt

# Event-driven interface, an onload handler
RP.stream.go = (evt) ->
	RP.submit.enqueue stream_fire, evt.target

RP.stream.fire = (elmt) ->
	RP.submit.enqueue stream_fire, elmt

do_item = (item, parent) ->
	if fcn = RP.named_function item.handler
		fcn.apply item
	else if item.elmt
		# Standard handling: convert text to HTML and append to list
		RP.appendElmt $(item.elmt), parent
	else
		RP.process_response item

stream_fire = (elmt) ->
	querypath = $(elmt).data('path')
	parent = RP.findEnclosingByClass 'stream-items-parent', elmt
	RP.submit.block_on parent
	$('.beachball', parent).removeClass "hide"
	$(elmt).remove() # Remove the link element to forestall subsequent loads
	# The following code represents two alternative ways of providing a set of items.
	# The 'if' clause is the sane way: issue a request for the set, then get them all
	#  and parse/process them as an array (a series of items)
	# The 'else' clause uses ActionController::Live to stream items individually. It's
	#  been obsoleted because it never worked properly.
	# However, the old functionality has been preserved. In addition to the below,
	# there's a corresponding choice block in #smartrender (application_controller.rb)
	if true
		ajoptions = {
			dataType: "json"
			contentType: "application/json",
			url: querypath,
			error: (jqXHR, statusText, errorThrown) ->
				responseData = RP.post_error(jqXHR) # Try to recover useable data from the error
				RP.submit.handleResponse parent, responseData, statusText, errorThrown
				RP.submit.block_off parent
			success: (responseData, statusText, xhr) ->
				# Expecting an array of items
				do_item item, parent for item in responseData
				RP.submit.block_off parent
			}
		$.ajax ajoptions
	else
		# It will be replaced when the trigger div gets replaced, IFF there's more material to come
		source = new EventSource querypath
		source.onerror = (evt) ->
			source.close()
			state = evt.target.readyState
			RP.submit.block_off parent
		source.addEventListener 'end_of_stream', (e) ->
			jdata = JSON.parse e.data
			source.close()
			RP.process_response jdata
			RP.submit.block_off parent
		source.addEventListener 'stream_item', (e) ->
			jdata = JSON.parse e.data
			do_item jdata, parent

RP.stream.buffer_test = ->
	source = new EventSource('/stream/buffer_test')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		jdata = JSON.parse e.data
		$('#seeker_results').append("<div>"+jdata.text+"</div>")
