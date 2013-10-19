
RP.stream ||= {}

jQuery ->
	# Set load handler to invoke stream and handle items
	$('div.collection div.streamer').each RP.stream.go

RP.stream.go = (index, elmt )->
	source = new EventSource('/stream/stream')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'collection_element', (e) ->
		jdata = JSON.parse e.data
		item = $(jdata.elmt)
		$('#masonry-container').append item
		$('#masonry-container').masonry 'appended', item
		
RP.stream.buffer_test = ->
	source = new EventSource('/stream/buffer_test')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		$('#masonry-container').append("<div>"+e.data+"</div>")

