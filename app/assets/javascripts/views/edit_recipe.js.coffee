# Support for editing recipe tags

RP.edit_recipe = RP.edit_recipe || {}

me = () ->
	$('div.edit_recipe')
tagger_selector = "div.edit_recipe #recipe_tag_tokens"

# Open the edit-recipe dialog on the recipe represented by 'rcpdata'
RP.edit_recipe.go = (rcpdata) ->
	template = $('#recipePowerEditRecipeTemplate')
	dlog = me()
	# If it has children it's active, and should be put away, starting with hiding it.
	if $('.edit_recipe > *').length > 0
		$(dlog).hide()
	# Parse the data for the recipe and insert into the dialog's template.
	# The dialog has placeholders of the form %%rcp<fieldname>%% for each part of the recipe
	# The status must be set by activating one of the options
	if templ = $(template).data "template"
		# ...but then again, the dialog may be complete without a template
		# statustarget = '<option value="'+rcpdata.rcpStatus+'"'
		# statusrepl = statustarget + ' selected="selected"'
		dlgsource = templ.string.
		replace(/%%rcpID%%/g, rcpdata.rcpID).
		replace(/%%rcpTitle%%/g, rcpdata.rcpTitle).
		replace(/%%rcpPicURL%%/g, rcpdata.rcpPicURL || "assets/MissingPicture.png" ).
		replace(/%%rcpPrivate%%/g, rcpdata.rcpPrivate).
		replace(/%%rcpComment%%/g, rcpdata.rcpComment).
		replace(/%%rcpStatus%%/g, rcpdata.rcpStatus).
		replace(/%%authToken%%/g, rcpdata.authToken) # .replace(statustarget, statusrepl)
		$(template).html dlgsource # This nukes any lingering children as well as initializing the dialog
	# The tag data is parsed and added to the tags field directly
	RP.tagger.init tagger_selector, jQuery.parseJSON(rcpdata.rcpTagData)
	
	# Hand it off to the dialog handler
	RP.dialog.run me()

# When dialog is loaded, activate its functionality
RP.edit_recipe.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.edit_recipe > *').length > 0
		
		# Setup tokenInput on the tags field
		RP.tagger.onload tagger_selector
		if $('.pic_picker_golink', dlog).length > 0
			# Get the picture picker in background
			RP.pic_picker.load (picdlg) ->
				$('.pic_picker_golink', dlog).removeClass('hide');
			
			# Arm the pic picker to open when clicked
			$(".pic_picker_golink", dlog).click ->
				event.preventDefault()
				return RP.pic_picker.open "Pick a Picture for the Recipe"
		
		# Fit the recipe's image into its place
		fitImageOnLoad "div.recipe_pic_preview img"
		
		# When submitting the form, we abort if there's no change
		# Stash the serialized form data for later comparison
		# $('form.edit_recipe').data "before", recipedata $('form.edit_recipe').serializeArray()
		dataBefore = recipedata $('form.edit_recipe', dlog).serializeArray()
		$('form.edit_recipe', dlog).data "hooks", {
			dataBefore: recipedata($('form.edit_recipe', dlog).serializeArray()),
			beforesaveFcn: "RP.edit_recipe.submission_redundant"
		}
		
		RP.makeExpandingArea $('div.expandingArea', dlog)
		
#		$('input.save-tags-button.cancel', dlog).click RP.edit_recipe.oncancel 
#		$('form.edit_recipe').on 'ajax:beforeSend', submission_redundant
#		$('form.edit_recipe').on 'ajax:success', submission_success
#		$('form#remove').on 'ajax:success', submission_success
#		$('form#destroy').on 'ajax:success', submission_success
		
		rcpid = $('form.edit_recipe', dlog).attr("id").replace /\D*/g, ''
		if touch_recipe = RP.named_function "RP.rcp_list.touch_recipe"
			touch_recipe rcpid

# Handle a close event: when the dialog is closed, also close its pic picker
RP.edit_recipe.onclose = (dlog) ->
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
RP.edit_recipe.submission_redundant = (dlog) ->
	# If the before and after states don't differ, we just close the dialog without submitting
	hooks = $('form.edit_recipe', dlog).data "hooks"
	dataBefore = hooks.dataBefore
	dataAfter = recipedata $('form.edit_recipe', dlog).serializeArray()
	for own attr, value of dataAfter
		if dataBefore[attr] != value # Something's changed => do normal forms processing
			return null
	# Nothing's changed => we can just silently close the dialog
	return { done: true, popup: "Sorted! Cookmark secure and unchanged." }
