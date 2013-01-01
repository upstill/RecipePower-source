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
	replace(/%%rcpPicURL%%/g, rcpdata.rcpPicURL).
	replace(/%%rcpPrivate%%/g, rcpdata.rcpPrivate).
	replace(/%%rcpComment%%/g, rcpdata.rcpComment).
	replace(/%%authToken%%/g, rcpdata.authToken).
	replace(statustarget, statusrepl)
	
	$(dlog).html dlgsource # This nukes any lingering children as well as initializing the dialog
	# The tag data is parsed and added to the tags field directly
	$("#recipe_tag_tokens").data "pre", jQuery.parseJSON(rcpdata.rcpTagData)
	
	# Invoke any onload functionality
	RP.edit_recipe.onload dlog # launchDialog dlog, "at_left", true # 
	# $('input.save-tags-button.save', dlog).click RP.edit_recipe.submit 
	# Arm the cancel button to close the dialog
	$('input.save-tags-button.cancel', dlog).click RP.edit_recipe.cancel 
	
	RP.rcp_list.touch_recipe rcpdata.rcpID

RP.edit_recipe.getandgo = (path, how, where) ->
	recipePowerGetAndRunJSON path, how, where

# Done with dialog: hide it and nuke its children
RP.edit_recipe.stop = (dlog) ->
	dlog = me()
	$(dlog).hide()
	RP.edit_recipe.onclose dlog
	$(dlog).empty()

RP.edit_recipe.cancel = (eventdata) ->
	RP.edit_recipe.stop()
	jNotify( "Cookmark secure and unharmed.", 
		{ HorizontalPosition: 'center', VerticalPosition: 'top'} );
	eventdata.preventDefault()

# When the dialog is closed, also close its pic picker
RP.edit_recipe.onclose = (dlog) ->
	picker_dlog = $("div.pic_picker")
	# If the dialog has an associated manager, call its onclose function
	if(RP && RP.dialog)
		RP.dialog.apply('onclose', picker_dlog)
	$(picker_dlog).dialog("destroy");
	$(picker_dlog).remove();
	
# Extract a name from a reference of the form "recipe[<name>]"
recipedata = (arr) ->
	result = new Object()
	$.each arr, ->
		if this.name.match(/recipe\[.*\]$/) 
			index = this.name.replace /^recipe\[(.*)\]/, "$1"
			result[index] = this.value
	result

# Don't submit if nothing has changed
before_send = (xhr) ->
	# If the before and after states don't differ, we just close the dialog without submitting
	dataBefore = $('form.edit_recipe').data "before"
	dataAfter = recipedata $('form.edit_recipe').serializeArray()
	me().hide()
	for own attr, value of dataAfter
		if dataBefore[attr] != value # Something's changed => do normal forms processing
			return true
	# Nothing's changed => we can just silently close the dialog
	RP.edit_recipe.stop()
	false

# Handle successful form submission: post the data and stop the dialog
success = (event, data, status, xhr) ->
	dlog = me()
	postSuccess data, dlog
	RP.edit_recipe.stop dlog
	true

# When dialog is loaded, activate its functionality
RP.edit_recipe.onload = (dlog) ->
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
		
		# Get the picture picker in background
		RP.pic_picker.load()
		
		# Arm the pic picker to open when clicked
		$("a.pic_picker_golink", dlog).click ->
			RP.pic_picker.open "Pick a Picture for the Recipe"
			event.preventDefault()
		
		# Fit the recipe's image into its place
		fitImageOnLoad "div.recipe_pic_preview img"
		
		# When submitting the form, we abort if there's no change
		# Stash the serialized form data for later comparison
		$('form.edit_recipe').data "before", recipedata($('form.edit_recipe').serializeArray())
		$('form.edit_recipe').on 'ajax:beforeSend', before_send
		$('form.edit_recipe').on 'ajax:success', success

jQuery ->
	if dlog = me()[0]
 		RP.edit_recipe.onload(dlog)

