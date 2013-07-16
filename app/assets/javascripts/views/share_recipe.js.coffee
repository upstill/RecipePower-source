# Support for editing recipe tags

RP.share_recipe = RP.share_recipe || {}

me = () ->
	$('div.share_recipe.dialog')

# When dialog is loaded, activate its functionality
RP.share_recipe.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.share_recipe > *').length > 0
		RP.tagger.onload "div.user_invitee_tokens input"
				
jQuery ->
	if dlog = me()[0]
 		RP.share_recipe.onload dlog
