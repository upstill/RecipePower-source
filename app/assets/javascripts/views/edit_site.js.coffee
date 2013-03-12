# Support for editing recipe tags

RP.edit_site = RP.edit_site || {}

me = () ->
	$('div.edit_site.dialog')

# When dialog is loaded, activate its functionality
RP.edit_site.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.edit_site > *').length > 0
				
		if $('.pic_picker_golink', dlog).length > 0
			# Get the picture picker in background
			RP.pic_picker.load (picdlg) ->
				$('.pic_picker_golink', dlog).removeClass('hide');
			
			# Arm the pic picker to open when clicked
			$(".pic_picker_golink", dlog).click ->
				event.preventDefault()
				return RP.pic_picker.open "Pick a Logo for the Site"
		
		# Fit the site's image into its place
		fitImageOnLoad "div.recipe_pic_preview img"

jQuery ->
	if dlog = me()[0]
 		RP.edit_site.onload dlog
