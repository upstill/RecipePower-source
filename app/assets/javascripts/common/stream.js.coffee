RP.stream ||= {}

RP.stream.go = ->
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
		jdata = JSON.parse e.data
		$('#masonry-container').append("<div>"+jdata.text+"</div>")

