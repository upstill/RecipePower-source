RP.pic_picker = RP.pic_picker || {}

me = () ->
	$('div.pic_picker')

RP.pic_picker.dlog = ->
	$('div.dialog.pic_picker')

# Prepare the picture picker prior to opening it.
RP.pic_picker.preload = (callback) ->
	dlog = me()
	# Don't load twice
	return if $(dlog).hasClass('loading')
	url = $(dlog).data "url"
	$(dlog).addClass('loading')
	$.ajax
		type: "GET",
		dataType: "html",
		url: url,
		error: (jqXHR, textStatus, errorThrown) ->
			x=2
		success: (response, statusText, xhr) ->
			# Pass any assumptions into the response data
			$(dlog).removeClass('loading')
			$(dlog).data "markup", response
			if jQuery.type(callback) == 'function'
				callback dlog

###
	$(dlog).load url, (responseText, textStatus, XMLHttpRequest) ->
		$(dlog).removeClass('loading')
###

RP.pic_picker.go = (odlog) ->
	# Arm the pic picker to open when clicked
	# RP.dialog.close_modal odlog
	marker_div = me()
	dlog_markup = $(marker_div).data "markup"
	RP.dialog.push_modal dlog_markup, odlog

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (dlog) ->
	$('.pic_picker_okay', dlog).click ->
		# Transfer the logo URL from the dialog's text input to the page text input
		# THE PICPICKER MUST BE ARMED WITH NAMES IN ITS DATA
		datavals = $(".pic_picker_golink").attr("data").split(';');
		previewImg("input.icon_picker", datavals[1], "input#"+datavals[0]);
		# Copy the image to the window's thumbnail
	$('a.image_preview_button').click ->
		previewImg('input.icon_picker', 'div.preview img', '')
	return true
	###
			$(dlog).dialog # nee: iconpicker
				modal: true,
				width: 700,
				zIndex: 1200,
				title: (ttl || "Pick a Picture"),
				buttons:
					Okay: (event) ->
						# Transfer the logo URL from the dialog's text input to the page text input
						# THE PICPICKER MUST BE ARMED WITH NAMES IN ITS DATA
						datavals = $(".pic_picker_golink").attr("data").split(';');
						previewImg("input.icon_picker", datavals[1], "input#"+datavals[0]);
						$(this).dialog('close');
						# Copy the image to the window's thumbnail
	###

# When a new URL is typed, set the (hidden) field box
# function newImageURL(inputsel, formsel, picid) {
# 	var url = $(inputsel).attr("value")
# 	var thePic = $("#"+picid)
# 	var formField = $(formsel)
# 	formField.attr("value", url);
# 	thePic.attr("src", url)
# 	return false;
# }

# Handle a click on a thumbnail image by passing the URL on to the
# associated input field
RP.pic_picker.make_selection = (url) ->
	$('input.icon_picker').attr "value", url
	previewImg 'input.icon_picker', 'div.preview img', ''

