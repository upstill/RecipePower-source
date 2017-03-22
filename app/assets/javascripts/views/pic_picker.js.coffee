RP.pic_picker ||= {}

# We try an image url by assigning it to an img element, then moving it to the input field if loaded successfully
preview_selector = 'div.preview img'

# Paste an image into the preview pane, pausing to save the previous image, if any, on the picker list
do_paste = (url) ->
	url ||= ''
	prior = $('input#pic-picker-url')[0].value # get_image preview_selector
	# Save the old image on the 'pic-pickees' list, if appropriate
	if prior.length > 1
		console.log "Saving image '" + prior + "'"
		matcher = null
		$('div.pic-pickees img.pic-pickee').each (ix) ->
			if this.src == prior
				matcher = this
		if !matcher
			txt = "<img src='" + prior + "' class='pic-pickee'>"
			$(txt).insertAfter "div.pic-pickees span.prompt"
	set_image_safely preview_selector, url, 'input#pic-picker-url'

focus_selector = 'div.preview' # input#pic-picker-magic'

arm_pane = (dlog_or_pane) ->
	# $('input#pic-picker-magic', dlog_or_pane).focus()
	$(focus_selector, dlog_or_pane).attr 'tabindex', 0
	$(focus_selector, dlog_or_pane).focus()
	if $('div.pic-pickees img:not(.bogus)').length == 0
		$('div.pic-pickees span.prompt').hide()

# When the pic_picker is activated in a dialog...
RP.pic_picker.activate = (pane) ->
	console.log "Pic-picker pane activated"
	arm_pane pane

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (dlog) ->
	# Here's how we handle image blobs (if the paste handler didn't handle it b/c it's not text)
	$('input[type="text"]', dlog).pasteImageReader (results) ->
		{filename, dataURL} = results
		do_paste dataURL
	# To handle pasting of page URLs, image URLS (including data:) and image blobs, we intercept the paste event
	document.getElementById('pic-picker-magic').addEventListener 'keypress', (e) ->
		e.preventDefault()
		e.stopPropagation();
	document.getElementById('pic-picker-magic').addEventListener 'keydown', (e) ->
		# if !(e.shiftKey || e.ctrlKey || e.altKey || e.metaKey || (e.keyCode == 8))
		if e.keyCode == 8 # Delete key removes the image
			do_paste()
			e.preventDefault()
			e.stopPropagation()
	document.getElementById('pic-picker-magic').addEventListener 'cut', do_paste
	document.getElementById('pic-picker-magic').addEventListener 'paste', (event) ->
		console.log "Paste into pic-picker magic"
		# Get pasted data via clipboard API
		clipboardData = event.clipboardData || window.clipboardData;
		contents = clipboardData.getData 'text'
		target_div = $('div#pic-picker-magic')[0]
		parse_actions contents, {
			url: ->
				console.log "...trying text as URL"
				# Fire the url-extract-button's URL, with the addition of the given URL
				elmt = event.target # $('a.url-extract-button')[0]
				request = RP.build_request $(target_div).data('gleaning-url'), { url: contents }
				RP.submit.enqueue request, target_div
				event.preventDefault()
			imgsrc: ->
				console.log "...pasted image URL"
				do_paste contents
				event.preventDefault()
			error: ->
				console.log "...bad/unparsable URL"
				if contents.length > 20
					contents = contents.slice(0, 20) + '...'
				RP.notifications.post "Sorry, but '" + contents + "' doesn't lead to an image. If you point your browser at it, does the image load?", 'flash-error'
				event.preventDefault()
		}
	if !$(dlog).hasClass 'pane' # Wait until the pane is activated to arm it
		arm_pane dlog
	# When the 'src' for the preview image is set and things settle down (for better or worse),
	# check the status and report as necessary.
	$(preview_selector).on 'ready', (event) ->
		if $(this).hasClass 'bogus'
			$('.dialog-submit-button', dlog).addClass 'disabled'
			RP.notifications.post "Sorry, but that address doesn't lead to an image. If you point your browser at it, does the image load?", 'flash-error'
		else
			$('.dialog-submit-button', dlog).removeClass 'disabled'
			if $(this).hasClass 'empty'
				prompt = 'to leave the recipe without an image.'
			else
				prompt = 'to use this image.'
			# RP.notifications.post 'Click Save '+prompt, 'flash-alert'

	# When an image in the select-list gets clicked, move it to the preview
	$(dlog).on 'click','img.pic-pickee', (event) ->
		clickee = RP.event_target event
		url = (clickee.getAttribute 'src')
		do_paste url

	# ...We can also upload files directly
	if uploader = $('input.directUpload', dlog)[0]
		uploader_init uploader

	# imagesLoaded fires when all the pickable images are either loaded or fail
	imagesLoaded 'img.pic-pickee', (instance) ->
		# Just in case: when all images are loaded, check for qualifying images that are still hidden
		$(':hidden', dlog).each (index, img) ->
			# We only allow images that are over 100 pixels in size, with a maximum A/R of 3
			if (img.tagName == 'IMG') && img.complete && (img.naturalWidth > 100 && img.naturalHeight > 100 && img.naturalHeight > (img.naturalWidth/3))
				$(img).show()
	return true

# This element is used to parse image URLs
parser = document.createElement 'a'

# Decide whether the 'contents' string represents:
# 	a URL leading to an image;
#   an arbitrary url, which will be gleaned for images for the pick-list
#   a 'data:' image string
# There is a callback in the options for each possibility
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
