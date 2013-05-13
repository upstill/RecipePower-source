RP.tag_list = RP.tag_list || {}

RP.tag_list.onload = ->
	debugger
	$('.tag_type_selector').change = (event) ->
		debugger
		# We're operating on the nearest table row element
		element = $(this).closest 'tr'
		#...which has the id of the tag to change
		regexp = new RegExp(".*_", "g")
		tagid = element.attr('id').replace regexp, ""
		node = element[0]
		# Our good old popup here has the new type of the tag
		value = $(this)[0].value
		# Fire off an Ajax call notifying the server of the (re)classification
		jQuery.get "/tags/typify",
			tagid: tagid
			newtype: value
			nuke_DOM_elements_by_id
			"json"
