RP.pic_picker ||= {}

# The link that opened the dialog
mylink = () ->
	$('a.pic_picker_golink')

originating_golink_selector = () ->
	if golinkid = $('input.icon_picker').data 'golinkid'
		return 'a#'+golinkid

# Clone the dialog and save the clone in the originating link
stash_in_golink = (dlog) ->
	clone = dlog.cloneNode true
	# The selector for the golink has been stored in data for the input
	$(originating_golink_selector()).data 'preloaded', clone

url_result = () ->
	$('input#pic-picker-url').attr('value')

# From wherever, set the picked URL value and load it into the proview (and result)
set_picker_input = (url) ->
	$('input.icon_picker').attr 'value', url
	load_picked_image()

load_picked_image = () ->
	previewImg 'input.icon_picker', 'div.preview img', 'input#pic-picker-url'

# The pic_picker dialog itself
mydlog = () ->
	$('div.dialog.pic_picker')

# Close with save
RP.pic_picker.close = (dlog) ->
	stash_in_golink dlog

# When the pic_picker is activated in a dialog...
RP.pic_picker.activate = (pane) ->
	console.log "Pic-picker pane activated"
	$('input#pic-picker-magic', pane).focus()

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (dlog) ->
	$(dlog).on 'paste', "#pic-picker-magic", (event) ->  # nee 'input'
		console.log "Paste into pic-picker magic"
		contents = event.originalEvent.clipboardData.getData 'text'
		parse_actions contents, {
			url: ->
				console.log "...trying text as URL"
				# Fire the url-extract-button's URL, with the addition of the given URL
				elmt = event.currentTarget # $('a.url-extract-button')[0]
				request = RP.build_request $(elmt).data('gleaning-url'), { url: contents }
				RP.submit.enqueue request, elmt
				event.preventDefault()
			imgsrc: ->
				console.log "...pasted image URL"
				# previewImg 'input#pic-picker-magic', 'div.preview img', 'input#pic-picker-url'
				set_image_safely 'div.preview img', contents, 'input#pic-picker-url'
				event.preventDefault()
			error: ->
				console.log "...bad/unparsable URL"
				if contents.length > 20
					contents = contents.slice(0, 20) + '...'
				RP.notifications.post "Sorry, but '" + contents + "' doesn't lead to an image. If you point your browser at it, does the image load?", 'flash-error'
		}

	$('input[type="text"]', dlog).pasteImageReader (results) ->
		{filename, dataURL} = results
		set_image_safely 'div.preview img', dataURL, 'input#pic-picker-url'

	# When the 'src' for an image is set and things settle down (for better or worse),
	# check the status and report as necessary.
	$('div.preview img').on 'ready', (event) ->
		if $(this).hasClass 'bogus'
			$('.dialog-submit-button', dlog).addClass 'disabled'
			RP.notifications.post "Sorry, but that address doesn't lead to an image. If you point your browser at it, does the image load?", 'flash-error'
		else
			$('.dialog-submit-button', dlog).removeClass 'disabled'
			if $(this).hasClass 'empty'
				prompt = 'to leave the recipe without an image.'
			else
				prompt = 'to use this image.'
			RP.notifications.post 'Click Save '+prompt, 'flash-alert'

	$(dlog).on 'click','a.image_preview_button', (event) ->
		load_picked_image()

	$(dlog).on 'click','a.url-extract-button', (event) ->
		# Fire the url-extract-button's URL, with the addition of the given URL
		elmt = event.currentTarget
		url = $('input.url_picker').attr('value')
		request = RP.build_request $(elmt).data('href'), { url: url }
		RP.submit.enqueue request, elmt
		event.preventDefault()

	$(dlog).on 'click','.dialog-submit-button', (event) ->
		url = url_result()
		if targetGolinkSelector = originating_golink_selector()
			RP.dialog.close event # Move on to tidying up
			# The input field points to the originating golink
			if linkdata = $(targetGolinkSelector).data()
				imagePreviewWidgetSet linkdata.imageid, linkdata.inputid, url

	$(dlog).on 'click','img.pic-pickee', (event) ->
		clickee = RP.event_target event
		set_picker_input (clickee.getAttribute 'src')

	$(dlog).on 'change', 'input.pic-picker-url', (event) ->
		clickee = RP.event_target event
		set_picker_input clickee.getAttribute('value')

	$('img.pic-pickee').load (evt) ->
		check_image this

	if uploader = $('input.directUpload', dlog)[0]
		uploader_init uploader

	$('img.pic-pickee').each (index, img) ->
		check_image img
		true

	# imagesLoaded fires when all the images are either loaded or fail
	imagesLoaded 'img.pic-pickee', (instance) ->
		# Just in case: when all images are loaded, check for qualifying images that are still hidden
		$(':hidden', dlog).each (index, img) ->
			check_image img
	return true

# Once an image is loaded, check that it's both complete (i.e., no errors) and of appropriate size and aspect ratio
check_image = (img) ->
	# We only allow images that are over 100 pixels in size, with a maximum A/R of 3
	if (img.tagName == 'IMG') && img.complete && (img.naturalWidth > 100 && img.naturalHeight > 100 && img.naturalHeight > (img.naturalWidth/3))
		$(img).show()

parser = document.createElement 'a'

parse_actions = (contents, options) ->
	if contents && contents.length > 0
		console.log "...text pasted: " + contents
		if contents.match(/^\s*https?:/) # A URL
			parser.href = contents;
			if parser.pathname.match /\.(jpg|jpeg|tif|tiff|gif|png)$/ # The input is an image URL
				(typeof options.imgsrc == 'function') && options.imgsrc()
			else
				(typeof options.url == 'function') && options.url()
		else if contents.match /^\s*data/
			(typeof options.imgsrc == 'function') && options.imgsrc()
		else
			(typeof options.error == 'function') && options.error()
