RP.pic_picker = RP.pic_picker || {}

mylink = () ->
	$('a.pic_picker_golink')

mydlog = () ->
	$('div.dialog.pic_picker')

# Prepare the picture picker prior to opening it.
RP.pic_picker.preload = (parent, callback) ->
	link = mylink()
	# Don't load twice
	return if $(link).hasClass('loading')
	url = link[0].href # $(dlog).data "url"
	$(link).addClass('loading')
	$.ajax
		type: "GET",
		dataType: "json",
		url: url,
		error: (jqXHR, textStatus, errorThrown) ->
			x=2
		success: (response, statusText, xhr) ->
			# Pass any assumptions into the response data
			$(link).removeClass('loading')
			$(link).data "response", response
			$(link).click ->
				event.preventDefault()
				RP.pic_picker.go parent
			if jQuery.type(callback) == 'function'
				callback link

###
	$(dlog).load url, (responseText, textStatus, XMLHttpRequest) ->
		$(dlog).removeClass('loading')
###

RP.pic_picker.go = (odlog) ->
	# Arm the pic picker to open when clicked
	# RP.dialog.close_modal odlog
	link = mylink()
	response = $(link).data "response"
	RP.dialog.push_modal response.dlog, odlog
	# RP.process_response response, odlog

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (dlog) ->
	$('.pic_picker_okay', dlog).click ->
		# Transfer the logo URL from the dialog's text input to the page text input
		# THE PICPICKER MUST BE ARMED WITH NAMES IN ITS DATA
		datavals = $(".pic_picker_golink").data("vals").split(';');
		previewImg("input.icon_picker", datavals[1], "input#"+datavals[0]);
		# Copy the image to the window's thumbnail
	$('a.image_preview_button').click ->
		previewImg('input.icon_picker', 'div.preview img', '')
	# $(dlog).removeClass('page').addClass('at_left')
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
						datavals = $(".pic_picker_golink").data("vals").split(';');
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

