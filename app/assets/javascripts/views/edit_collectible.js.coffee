# Support for editing recipe tags

RP.edit_collectible = RP.edit_collectible || {}

jQuery ->
	RP.edit_collectible.bind()

# Handle editing links
RP.edit_collectible.bind = (dlog) ->
	dlog ||= $('body') # window.document
	# Set up processing for click events on links with a 'edit-collectible-link' class
	$(dlog).on "click", 'a.template.edit-collectible', RP.edit_collectible.go

me = () ->
	$('div.edit-collectible')[0]

tagger_selector = "div.edit-collectible #tagging_tokens"

# Open the edit-recipe dialog on the recipe represented by 'rcpdata'
RP.edit_collectible.go = (evt, xhr, settings) ->
	RP.edit_collectible.apply_template this
	false

RP.edit_collectible.apply_template = (elmt) ->
	dlog = me()
	templateData = $(elmt).data "template"
	# If it has children it's active, and should be put away, starting with hiding it.
	if $('.edit-collectible > *').length > 0
		$(dlog).hide()
	# Parse the data for the recipe and insert into the dialog's template.
	# The dialog has placeholders of the form %%rcp<fieldname>%% for each part of the recipe
	# The status must be set by activating one of the options
	templateData.subs.picdata ||= templateData.subs.picurl || "/assets/NoPictureOnFile.png"  # Default
	RP.templates.interpolate templateData
	# The tag data is parsed and added to the tags field directly
	RP.tagger.init tagger_selector, templateData.subs.taggingTagData
	$('textarea').autosize()

	# Hand it off to the dialog handler
	RP.dialog.run me()
	# When submitting the form, we abort if there's no change
	# Stash the serialized form data for later comparison
	# $('form.edit-collectible').data "before", recipedata $('form.edit-collectible').serializeArray()
	dataBefore = recipedata $('form.edit-collectible', dlog).serializeArray()
	$('form.edit-collectible', dlog).data "hooks", {
		dataBefore: recipedata($('form.edit-collectible', dlog).serializeArray()),
		beforesaveFcn: "RP.edit_collectible.submission_redundant"
	}
	RP.makeExpandingArea $('div.expandingArea', dlog)
	dlog

# When dialog is loaded, activate its functionality
RP.edit_collectible.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.edit-collectible > *').length > 0
		# The pic picker is preloaded onto its link element. Unhide the link when loading is complete
		rcpid = $('form.edit-collectible', dlog).attr("id").replace /\D*/g, ''
		if touch_recipe = RP.named_function "RP.rcp_list.touch_recipe"
			touch_recipe rcpid

# Handle a close event: when the dialog is closed, also close its pic picker
RP.edit_collectible.onclose = (dlog) ->
	if picker_dlog = $("div.pic_picker")
		$(picker_dlog).remove();
	return true # Prevent normal close action

# Extract a name from a reference of the form "recipe[<name>]"
recipedata = (arr) ->
	result = new Object()
	$.each arr, ->
		if this.name.match(/recipe\[.*\]$/)
			index = this.name.replace /^recipe\[(.*)\]/, "$1"
			result[index] = this.value
	result

# Don't submit if nothing has changed
RP.edit_collectible.submission_redundant = (dlog) ->
	# If the before and after states don't differ, we just close the dialog without submitting
	hooks = $('form.edit-collectible', dlog).data "hooks"
	dataBefore = hooks.dataBefore
	dataAfter = recipedata $('form.edit-collectible', dlog).serializeArray()
	for own attr, value of dataAfter
		if dataBefore[attr] != value # Something's changed => do normal forms processing
			return null
	# Nothing's changed => we can just silently close the dialog
	return { done: true, popup: "Sorted! Cookmark secure and unchanged." }
