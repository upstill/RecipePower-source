RP.stream ||= {}

RP.stream.go = (elmt) ->
	me = elmt # evt.currentTarget
	# Check with the stream generator for content
	kind = $(elmt).data('kind')
	$(elmt).remove()
	source = new EventSource "/stream/stream?kind="+kind
	source.onerror = (evt) ->
		state = evt.target.readyState
		debugger
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'stream_item', (e) ->
		jdata = JSON.parse e.data
		# If the item specifies a handler, call that
		if handler = jdata.handler && fcn = RP.named_function
			fcn.apply jdata
		else # Standard handling: append to a parent designated by selector
			item = $(jdata.elmt)
			selector = jdata.selector || '.collection_list'
			$(selector).append item
			if selector == '#masonry-container'
				$('#masonry-container').masonry 'appended', item
				if img = $('div.recipe_image_div img', item)[0]
					srcstr = img.getAttribute('src')
					contentstr = "<img src=\""+srcstr+"\" style=\"width: 100%; height: auto\">"
				else
					contentstr = ""
				# Any (hopefully few) pictures that are loaded from URL will resize the element
				# when they appear.
				$(item).on 'resize', (evt) ->
					$('#masonry-container').masonry()
				datablock = $('span.recipe-info-button', item)
				tagstr = $(datablock).data "tags"
				decoded = $('<div/>').html(tagstr).text();
				$(datablock).popover
					trigger: "click",
					placement: "auto right",
					html: true,
					content: contentstr+decoded

RP.stream.buffer_test = ->
	source = new EventSource('/stream/buffer_test')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		jdata = JSON.parse e.data
		$('#masonry-container').append("<div>"+jdata.text+"</div>")

