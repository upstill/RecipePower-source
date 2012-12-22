# Support for editing recipe tags

RP.edit_recipeOnload = (dlog) ->
	$("#recipe_tag_tokens").tokenInput("/tags/match.json", 
		crossDomain: false,
		noResultsText: "No matching tag found; hit Enter to make it a tag",
		hintText: "Type your own tag(s) for the recipe",
		prePopulate: $("#recipe_tag_tokens").data("pre"),
		theme: "facebook",
		preventDuplicates: true,
		allowFreeTagging: true
	)
	$("a.pic_picker_golink").click ->
		PicPicker "Pick a Picture for the Recipe"
		event.preventDefault()
	fitImageOnLoad "div.edit_recipe img"
	# dialogOnClose dlog, recipeCallback 
	
RP.edit_recipeGo = (path, how, where) ->
	recipePowerGetAndRunJSON path, how, where

jQuery ->
	if dlog = $('div.edit_recipe.dialog')[0]
		RP.edit_recipeOnload(dlog)

