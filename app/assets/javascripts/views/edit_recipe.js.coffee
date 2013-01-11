# Support for editing recipe tags

RP.edit_recipe = RP.edit_recipe || {}

me = () ->
	$('div.edit_recipe.dialog')

# Open the edit-recipe dialog on the recipe represented by 'rcpdata'
RP.edit_recipe.go = (rcpdata) ->
	dlog = me()
	# If it has children it's active, and should be put away, starting with hiding it.
	if $('.edit_recipe > *').length > 0
		$(dlog).hide()
		
	# Parse the data for the recipe and insert into the dialog's template.
	# The dialog has placeholders of the form %%rcp<fieldname>%% for each part of the recipe
	# The status must be set by activating one of the options
	statustarget = '<option value="'+rcpdata.rcpStatus+'"'
	statusrepl = statustarget + ' selected="selected"'
	dlgsource = $(dlog).data("template").string.
	replace(/%%rcpID%%/g, rcpdata.rcpID).
	replace(/%%rcpTitle%%/g, rcpdata.rcpTitle).
	replace(/%%rcpPicURL%%/g, rcpdata.rcpPicURL || "assets/MissingPicture.png" ).
	replace(/%%rcpPrivate%%/g, rcpdata.rcpPrivate).
	replace(/%%rcpComment%%/g, rcpdata.rcpComment).
	replace(/%%authToken%%/g, rcpdata.authToken).
	replace(statustarget, statusrepl)
	
	$(dlog).html dlgsource # This nukes any lingering children as well as initializing the dialog
	# The tag data is parsed and added to the tags field directly
	$("#recipe_tag_tokens").data "pre", jQuery.parseJSON(rcpdata.rcpTagData)
	
	# Hand it off to the dialog handler
	launchDialog dlog, "at_left", true

RP.edit_recipe.stop = ->
	# Close the recipe editor, if it's open
	closeModeless me()

# When dialog is loaded, activate its functionality
RP.edit_recipe.onload = (dlog) ->
	dlog = me()
	# Only proceed if the dialog has children
	if $('.edit_recipe > *').length > 0
		$(dlog).show 500
		# Setup tokenInput on the tags field
		$("#recipe_tag_tokens", dlog).tokenInput("/tags/match.json", 
			crossDomain: false,
			noResultsText: "No matching tag found; hit Enter to make it a tag",
			hintText: "Type your own tag(s) for the recipe",
			prePopulate: $("#recipe_tag_tokens").data("pre"),
			theme: "facebook",
			preventDuplicates: true,
			allowFreeTagging: true
		)
		
		if $('a.pic_picker_golink', dlog).length > 0
			# Get the picture picker in background
			RP.pic_picker.load (picdlg) ->
				$('a.pic_picker_golink', dlog).addClass('loaded');
			
			# Arm the pic picker to open when clicked
			$("a.pic_picker_golink", dlog).click ->
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
			saveMsg: "Cookmark successfully saved.",
			beforesaveFcn: "RP.edit_recipe.submission_redundant"
		}
		
		$('input.save-tags-button.cancel', dlog).data "hooks",
		 	successMsg: "Cookmark secure and unharmed."
		$('form.remove', dlog).data "hooks",
		 	saveMsg: "Cookmark removed from collection."
		$('form.destroy', dlog).data "hooks",
	 		saveMsg: "Cookmark destroyed for now and evermore."

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
	$(dlog).hide()
	picker_dlog = $("div.pic_picker")
	closeModal(picker_dlog)
	$(dlog).empty()
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
			return false
	# Nothing's changed => we can just silently close the dialog
	true

jQuery ->
	if dlog = me()[0]
 		RP.edit_recipe.onload(dlog)

