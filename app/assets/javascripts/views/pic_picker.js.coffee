RP.pic_picker = RP.pic_picker || {}

RP.pic_picker.arm = (event) ->

###
	$(dlog).on 'preload', 'a.pic_picker_golink', ->
###

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
			RP.notifications.post "Sorry, but that address doesn't lead to an image. Does it appear if you point your browser at it?", "flash-error"
		else
			$('a.dialog-submit-button', dlog).removeClass 'disabled'
			RP.notifications.post "Click Save to use this image.", "flash-alert"
	$('a.image_preview_button').click ->
		previewImg('input.icon_picker', 'div.preview img', '')
		# imagePreviewWidgetSet($('input.icon_picker').attr("value"), 'div.preview img', '')
	$('img.pic_pickee').click (event) ->
		clickee = RP.event_target event
		url = clickee.getAttribute 'src'
		$('input.icon_picker').attr "value", url
		previewImg 'input.icon_picker', 'div.preview img', ''
	$('img.pic_pickee').each (index, img) ->
		check_image img
		true
	###
	$('div#masonry-pic-pickees', dlog).masonry
		columnWidth: 100,
		gutter: 20,
		itemSelector: '.pic_pickee_loaded'
	###
	$('img.pic_pickee').load (evt) ->
		check_image this #, $('div#masonry-pic-pickees', dlog)
	# imagesLoaded fires when all the images are loaded
	imagesLoaded 'img.pic_pickee', (instance) ->
		# Just in case: when all images are loaded, check for qualifying images that are still hidden
		$(':hidden', dlog).each (index, img) ->
			check_image img #, $('div#masonry-pic-pickees', dlog)
	return true

check_image = (img, masonrySet) ->
	# We only allow images that are over 100 pixels in size, with a maximum A/R of 3
	if (img.tagName == "IMG") && img.complete && (img.naturalWidth > 100 && img.naturalHeight > 100 && img.naturalHeight > (img.naturalWidth/3))
		console.log "img "+$(img).attr("id")+": "+img.naturalWidth+" x "+img.naturalHeight
		$(img).show()
		$(img).addClass "pic_pickee_loaded"
		masonrySet.masonry('appended', img) if masonrySet

# Handle a click on a thumbnail image by passing the URL on to the
# associated input field
RP.pic_picker.make_selection = (url) ->
	$('input.icon_picker').attr "value", url
	previewImg 'input.icon_picker', 'div.preview this', ''
	# imagePreviewWidgetSet 'input.icon_picker', 'div.preview this', ''

