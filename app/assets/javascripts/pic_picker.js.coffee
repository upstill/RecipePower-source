RP.pic_picker = RP.pic_picker || {}

me = () ->
	$('div.pic_picker')

loaded = ""

# Prepare the picture picker prior to opening it.
RP.pic_picker.load = (rcpid) ->
	dlog = me()
	url = $(dlog).data("url")
	loaded = ""
	$(dlog).load(url, (responseText, textStatus, XMLHttpRequest) ->
		loaded = url
	)

# Respond to a link by bringing up a dialog for picking among the image fields of a page
# -- the pic_picker div is ready to be a diaog
# -- the data of the link must contain urls for each image, separated by ';'
# formerly PicPicker
RP.pic_picker.open = (ttl) ->
	dlog = me()
	url = $(dlog).data("url")
	if loaded == url
		$(dlog).dialog # nee: iconpicker
			modal: true,
			width: 700,
			zIndex: 1200,
			title: (ttl || "Pick a Picture"),
			buttons:
				Okay: (event) ->
					# Transfer the logo URL from the dialog's text input to the page text input
					# THE PICPICKER MUST BE ARMED WITH NAMES IN ITS DATA
					datavals = $("a.pic_picker_golink").attr("data").split(';');
					previewImg("input.icon_picker", datavals[1], "input#"+datavals[0]);
					$(this).dialog('close');
					# Copy the image to the window's thumbnail

# When a new URL is typed, set the (hidden) field box
# function newImageURL(inputsel, formsel, picid) {
# 	var url = $(inputsel).attr("value")
# 	var thePic = $("#"+picid)
# 	var formField = $(formsel)
# 	formField.attr("value", url);
# 	thePic.attr("src", url)
# 	return false;
# }
