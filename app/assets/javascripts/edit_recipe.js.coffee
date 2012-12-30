# Support for editing recipe tags

RP.edit_recipe = RP.edit_recipe || {}

# Open the edit-recipe dialog on the recipe represented by 'rcpdata'
RP.edit_recipe.go = (rcpdata) ->
	dlog = $('div.edit_recipe.dialog')
	# If it has children it's active, and should be put away, starting with hiding it.
	if $('.edit_recipe > *').length > 0
		$(dlog).hide()
		
	# Parse the data for the recipe and insert into the dialog's template.
	# The dialog has placeholders of the form %%rcp<fieldname>%% for each part of the recipe
	dlgdata = $(dlog).attr "template" # XXX should be stored in 'data-template' per HTML5
	obj = jQuery.parseJSON dlgdata
	dlgsource = unescape obj.string
	dlgsource = dlgsource.
	replace(/%%rcpID%%/g, rcpdata.rcpID).
	replace(/%%rcpTitle%%/g, rcpdata.rcpTitle).
	replace(/%%rcpPicURL%%/g, rcpdata.rcpPicURL).
	replace(/%%rcpPrivate%%/g, rcpdata.rcpPrivate).
	replace(/%%rcpComment%%/g, rcpdata.rcpComment).
	replace(/%%rcpStatus%%/g, rcpdata.rcpStatus)
	$(dlog).html dlgsource # This nukes any lingering children as well as initializing the dialog
	# The tag data is parsed and added to the tags field directly
	tagdata = jQuery.parseJSON rcpdata.rcpTagData
	$("#recipe_tag_tokens").data "pre", tagdata
	
	# Invoke any onload functionality
	RP.edit_recipe.onload dlog # launchDialog dlog, "at_left", true # 
	# $('input.save-tags-button.save', dlog).click RP.edit_recipe.submit 
	# Arm the cancel button to close the dialog
	$('input.save-tags-button.cancel', dlog).click RP.edit_recipe.cancel 

RP.edit_recipe.getandgo = (path, how, where) ->
	recipePowerGetAndRunJSON path, how, where

# Done with dialog: hide it and nuke its children
RP.edit_recipe.stop = (dlog) ->
	dlog = $('div.edit_recipe.dialog')
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

# When dialog is loaded, activate its functionality
RP.edit_recipe.onload = (dlog) ->
	# Only proceed if the dialog has children
	if $('.edit_recipe > *').length > 0
		$('form.edit_recipe').on 'ajax:success', (event, data, status, xhr) ->
			postSuccess data, dlog
			RP.edit_recipe.stop dlog
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
		# Arm the pic picker to open when clicked
		$("a.pic_picker_golink", dlog).click ->
			PicPicker "Pick a Picture for the Recipe"
			event.preventDefault()
		# Fit the recipe's image into its place
		fitImageOnLoad "div.recipe_pic_preview img"
		$(dlog).show 500

jQuery ->
	if dlog = $('div.edit_recipe.dialog')[0]
 		RP.edit_recipe.onload(dlog)

