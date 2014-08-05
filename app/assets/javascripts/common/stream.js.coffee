RP.stream ||= {}

# Event-driven interface, an onload handler
RP.stream.go = (evt) ->
	RP.stream.fire evt.target

RP.stream.fire = (elmt) ->
	elmt.innerHTML = "Recipes are on their way..."
	querypath = $(elmt).data('path')
	container_selector = $(elmt).data('containerSelector') || ""
	container_selector += " .stream-items-parent"
	source = new EventSource querypath
	source.onerror = (evt) ->
		source.close()
		state = evt.target.readyState
	source.addEventListener 'end_of_stream', (e) ->
		jdata = JSON.parse e.data
		source.close()
		if jdata.more_to_come
			RP.collection.more_to_come jdata.more_to_come
		RP.process_response jdata
	source.addEventListener 'stream_item', (e) ->
		jdata = JSON.parse e.data
		# If the item specifies a handler, call that
		if handler = jdata.handler && fcn = RP.named_function
			fcn.apply jdata
		else # Standard handling: append to the seeker_table
			item = $(jdata.elmt)
			# selector = jdata.selector || '.collection_list'
			# $(selector).append item
			$(container_selector).append item
			if $(container_selector).hasClass 'masonry-container'
				masonry_selector = container_selector+'.masonry-container'
				$(masonry_selector).masonry 'appended', item
				# Any (hopefully few) pictures that are loaded from URL will resize the element
				# when they appear.
				$(item).on 'resize', (evt) ->
					$(masonry_selector).masonry()
				RP.rcp_list.onload $('div.collection-item',item)

RP.stream.buffer_test = ->
	source = new EventSource('/stream/buffer_test')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		jdata = JSON.parse e.data
		$('#seeker_results').append("<div>"+jdata.text+"</div>")

RP.stream.tagchange = (selector) ->
	# Find the enclosing parent
	formelmt = this[0].parentNode
	while formelmt.tagName != 'FORM'
		formelmt = formelmt.parentNode
	if $(formelmt).data("format") == "html"
		$(formelmt).submit()
	else
		data = $(formelmt).serialize()
		# Add the serialized form data to the action, accounting for existing query
		request = $(formelmt).attr("action")
		rsplit = request.split '?'
		delim = '?'
		if rsplit.length > 1
			if rsplit[1].length == 0 # Empty query
				request = rsplit[0]
			else
				delim = '&'
		qt = $(formelmt).serialize()
		queries = qt.split("&");

		# Cycle through the elements of the query, eliminating those with an empty value
		for qstr in qt.split('&')
			temp = qstr.split('=');
			if temp[1] && temp[1].length > 0
				request = request + delim + qstr
			delim = '&'

		RP.submit.submit_and_process request, "GET",
			wait_msg: "Here goes nothin'..."
