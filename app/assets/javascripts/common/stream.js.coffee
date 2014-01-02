RP.stream ||= {}

# Event-driven interface, an onload handler
RP.stream.go = (evt) ->
	elmt = evt.target
	RP.stream.fire $(elmt).data('kind')

# jQuery-driven interface
RP.stream.fire = (kind) ->
	# Check with the stream generator for content
	source = new EventSource "/stream/stream?kind="+kind
	source.onerror = (evt) ->
		state = evt.target.readyState
	source.addEventListener 'end_of_stream', (e) ->
		jdata = JSON.parse e.data
		source.close()
		RP.collection.more_to_come jdata.more_to_come
	source.addEventListener 'stream_item', (e) ->
		jdata = JSON.parse e.data
		# If the item specifies a handler, call that
		if handler = jdata.handler && fcn = RP.named_function
			fcn.apply jdata
		else # Standard handling: append to the seeker_table
			item = $(jdata.elmt)
			# selector = jdata.selector || '.collection_list'
			# $(selector).append item
			$('#seeker_results').append item
			if $('#seeker_results').hasClass 'masonry-container'
				$('#seeker_results.masonry-container').masonry 'appended', item
				if img = $('div.rcp_grid_pic_box img', item)[0]
					srcstr = img.getAttribute('src')
					contentstr = "<img src=\""+srcstr+"\" style=\"width: 100%; height: auto\">"
				else
					contentstr = ""
				# Any (hopefully few) pictures that are loaded from URL will resize the element
				# when they appear.
				$(item).on 'resize', (evt) ->
					$('#seeker_results.masonry-container').masonry()
				datablock = $('span.recipe-info-button', item)
				tagstr = $(datablock).data "tags"
				decoded = $('<div/>').html(tagstr).text();
				description = $(datablock).data "description"
				descripted = (description && $('<div/>').html(description).text()) || "";
				$(datablock).popover
					trigger: "hover",
					placement: "auto right",
					html: true,
					content: descripted+contentstr+decoded

RP.stream.buffer_test = ->
	source = new EventSource('/stream/buffer_test')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		jdata = JSON.parse e.data
		$('#seeker_results').append("<div>"+jdata.text+"</div>")

