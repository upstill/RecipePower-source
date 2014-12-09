# Support for editing recipe tags

RP.tag_collectible = RP.tag_collectible || {}

jQuery ->
	RP.tag_collectible.bind()

# Handle editing links
RP.tag_collectible.bind = (dlog) ->
	dlog ||= $('body') # window.document
	# Set up processing for click events on links with a 'tag-collectible-link' class
	$(dlog).on "click", 'a.template.tag-collectible', RP.tag_collectible.go

me = () ->
	$('div.tag-collectible')[0]

tagger_selector = "div.tag-collectible #tagging_tokens"

# Open the edit-recipe dialog on the recipe represented by 'rcpdata'
RP.tag_collectible.go = (evt, xhr, settings) ->
	RP.tag_collectible.apply_template this
	false

RP.tag_collectible.apply_template = (elmt) ->
	dlog = me()
	templateData = $(elmt).data "template"
	unless templateData && templateData.subs
		return null
	# If it has children it's active, and should be put away, starting with hiding it.
	if $('.tag-collectible > *').length > 0
		$(dlog).hide()
	# Parse the data for the recipe and insert into the dialog's template.
	# The dialog has placeholders of the form %%rcp<fieldname>%% for each part of the recipe
	# The status must be set by activating one of the options
	templateData.subs.picdata ||= templateData.subs.picurl || "/assets/NoPictureOnFile.png"  # Default
	unless srcString = RP.templates.find_and_interpolate templateData
		return null
	# The tag data is parsed and added to the tags field directly
	RP.tagger.init tagger_selector, templateData.subs.taggingTagData
	$('textarea').autosize()

	# Hand it off to the dialog handler
	RP.dialog.run me()
	# When submitting the form, we abort if there's no change
	# Stash the serialized form data for later comparison
	# $('form.tag-collectible').data "before", recipedata $('form.tag-collectible').serializeArray()
	dataBefore = recipedata $('form.tag-collectible', dlog).serializeArray()
	$('form.tag-collectible', dlog).data "hooks", {
		dataBefore: recipedata($('form.tag-collectible', dlog).serializeArray()),
		beforesaveFcn: "RP.tag_collectible.submission_redundant"
	}
	RP.makeExpandingArea $('div.expandingArea', dlog)
	dlog

# When dialog is loaded, activate its functionality
RP.tag_collectible.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.tag-collectible > *').length > 0
		# The pic picker is preloaded onto its link element. Unhide the link when loading is complete
		rcpid = $('form.tag-collectible', dlog).attr("id").replace /\D*/g, ''
		if touch_recipe = RP.named_function "RP.rcp_list.touch_recipe"
			touch_recipe rcpid

# Handle a close event: when the dialog is closed, also close its pic picker
RP.tag_collectible.onclose = (dlog) ->
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
RP.tag_collectible.submission_redundant = (dlog) ->
	# If the before and after states don't differ, we just close the dialog without submitting
	hooks = $('form.tag-collectible', dlog).data "hooks"
	dataBefore = hooks.dataBefore
	dataAfter = recipedata $('form.tag-collectible', dlog).serializeArray()
	for own attr, value of dataAfter
		if dataBefore[attr] != value # Something's changed => do normal forms processing
			return null
	# Nothing's changed => we can just silently close the dialog
	return { done: true, popup: "Sorted! Cookmark secure and unchanged." }
