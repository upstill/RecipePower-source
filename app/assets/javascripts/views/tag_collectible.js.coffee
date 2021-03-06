# Support for editing recipe tags

RP.tag_collectible = RP.tag_collectible || {}

jQuery ->
	RP.tag_collectible.bind()

# Handle editing links
RP.tag_collectible.bind = (dlog) ->
	dlog ||= $('body') # window.document
	# Set up processing for click events on links with a 'tag-collectible-link' class

mydlog = () ->
	$('div.dialog.tag-collectible')[0] || $('div.pane#tag-collectible-pane').closest('div.dialog')[0]

mypane = () ->
	$('div.pane#tag-collectible-pane')[0] || $('div.dialog.tag-collectible')[0]

# When dialog is loaded, activate its functionality
RP.tag_collectible.onopen = (dlog) ->
	dlog = mydlog()
	# Only proceed if the dialog has children
	if $('.tag-collectible > *').length > 0
		# Set up any tokenInput fields so the before-data is current
		RP.tagger.onopen()
		$('form.tag-collectible', dlog).data "hooks",
				dataBefore: $('form.tag-collectible', dlog).serialize(), # recipedata($('form.tag-collectible', dlog).serializeArray()),
				beforesaveFcn: "RP.tag_collectible.submission_redundant"
		# Report back to the server that we've touched the recipe
		touch_request = $('form.tag-collectible', dlog)[0].action.replace(/\/tag.*/,'/touch')
		jQuery.get touch_request, {}, (body, status, instance) ->
			return true
		, "json"

# Handle a close event: when the dialog is closed, also close its pic picker
RP.tag_collectible.onclose = (dlog) ->
	if picker_dlog = $("div.pic_picker")
		$(picker_dlog).remove();
	return true # Prevent normal close action

# Extract a name from a reference of the form "recipe[<name>]"
###
recipedata = (arr) ->
	result = new Object()
	$.each arr, ->
		if this.name.match(/recipe\[.*\]$/)
			index = this.name.replace /^recipe\[(.*)\]/, "$1"
			result[index] = this.value
	result
###

# Don't submit if nothing has changed
RP.tag_collectible.submission_redundant = (dlog) ->
	# If the image is not data, write anyway, in order to trigger an attempt to set the thumbnail data
	if $('form.tag-collectible', dlog).data "always_submit"
		return false
	# If the before and after states don't differ, we just close the dialog without submitting
	hooks = $('form.tag-collectible', dlog).data "hooks"
	if hooks.dataBefore == $('form.tag-collectible', dlog).serialize()
		return { done: true, popup: "Sorted! Cookmark secure and unchanged." }
#	for own attr, value of dataAfter
#		if dataBefore[attr] != value # Something's changed => do normal forms processing
#			return null
#	# Nothing's changed => we can just silently close the dialog
