RP.pic_picker ||= {}

mylink = () ->
	$('a.pic_picker_golink')

mydlog = () ->
	$('div.dialog.pic_picker')

# Close with save
RP.pic_picker.close = (dlog) ->
	# Transfer the logo URL from the dialog's text input to the page text input

	# The input field points to the originating golink
	targetGolinkSelector = "a#"+$("input.icon_picker").data('golinkid')

	# The golink points to the original image and/or input fields
	if !$('div.preview img').hasClass 'bogus'
		linkdata = $(targetGolinkSelector).data()
		url = $("input.icon_picker").attr("value")
		imagePreviewWidgetSet linkdata.imageid, linkdata.inputid, url

	# Finally, clone the dialog and save the clone in the link for later
	clone = dlog.cloneNode true
	$(targetGolinkSelector).data 'preloaded', clone

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (dlog) ->
	$('div.preview img').on 'ready', (event) ->
		if $(this).hasClass 'bogus'
			$('a.dialog-submit-button', dlog).addClass 'disabled'
			RP.notifications.post "Sorry, but that address doesn't lead to an image. If you point your browser at it, does the image load?", "flash-error"
		else
			$('a.dialog-submit-button', dlog).removeClass 'disabled'
			if $(this).hasClass 'empty'
				prompt = "to leave the recipe without an image."
			else
				prompt = "to use this image."
			RP.notifications.post "Click Save "+prompt, "flash-alert"

	$('a.image_preview_button').click ->
		previewImg('input.icon_picker', 'div.preview img', '')
		# imagePreviewWidgetSet($('input.icon_picker').attr("value"), 'div.preview img', '')

	$('img.pic_pickee').click (event) ->
		clickee = RP.event_target event
		url = clickee.getAttribute 'src'
		$('input.icon_picker').attr "value", url
		previewImg 'input.icon_picker', 'div.preview img', ''

	$('img.pic_pickee').load (evt) ->
		check_image this

	$('img.pic_pickee').each (index, img) ->
		check_image img
		true

	# imagesLoaded fires when all the images are either loaded or fail
	imagesLoaded 'img.pic_pickee', (instance) ->
		# Just in case: when all images are loaded, check for qualifying images that are still hidden
		$(':hidden', dlog).each (index, img) ->
			check_image img
	return true

# Once an image is loaded, check that it's both complete (i.e., no errors) and of appropriate size and aspect ratio
check_image = (img) ->
	# We only allow images that are over 100 pixels in size, with a maximum A/R of 3
	if (img.tagName == "IMG") && img.complete && (img.naturalWidth > 100 && img.naturalHeight > 100 && img.naturalHeight > (img.naturalWidth/3))
		$(img).show()

# Handle a click on a thumbnail image by passing the URL on to the
# associated input field
RP.pic_picker.make_selection = (url) ->
	previewImg 'input.icon_picker', 'div.preview this', ''
