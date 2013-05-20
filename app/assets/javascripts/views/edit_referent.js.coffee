# Support for editing referent tags

RP.edit_referent = RP.edit_referent || {}

me = () ->
	$('div.edit_referent')
tagger_selector = "div.edit_referent input#referent_add_expression"

# When dialog is loaded, activate its functionality
RP.edit_referent.onload = (dlog) ->
	debugger
	dlog = me()
	# Setup tokenInput on the tags field
	RP.tagger.onload tagger_selector
