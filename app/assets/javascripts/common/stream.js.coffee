
RP.stream ||= {}

jQuery ->
	# Set load handler to invoke stream and handle items
	debugger
	$('div.collection div.streamer').each RP.stream.go

RP.stream.go = (index, elmt )->
	source = new EventSource('/stream/stream')
	source.addEventListener 'end_of_stream', (e) ->
		source.close()
	source.addEventListener 'message', (e) ->
		$('#masonry-container').append("<div>"+e.data+"</div>")
	source.addEventListener 'collection_element', (e) ->
		debugger
		jdata = e.data # JSON.parse e.data
		$('#masonry-container').append(jdata)
		# $('#masonry-container').masonry( 'addItems', $('#masonry-container').append(jdata.elmt) );	