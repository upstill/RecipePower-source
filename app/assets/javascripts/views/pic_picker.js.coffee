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

# Replace the dialog by with one generated from a different page
extract_from_page = (event) ->
	# Fire the url-extract-button's URL, with the addition of the given URL
	elmt = event.currentTarget
	request = RP.build_request $(elmt).data('href'), { url: $('input.url_picker').attr('value') }
	RP.submit.enqueue request, elmt
	event.preventDefault()

# The pic_picker dialog itself
mydlog = () ->
	$('div.dialog.pic_picker')

# Close with save
RP.pic_picker.close = (dlog) ->
	stash_in_golink dlog

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (dlog) ->
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
		extract_from_page(event)

	$('input[type="text"]', dlog).pasteImageReader (results) ->
		{filename, dataURL} = results
		set_image_safely 'div.preview img', dataURL, 'input#pic-picker-url'

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
