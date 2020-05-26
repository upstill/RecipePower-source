# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

RP.recipe_contents ||= {}

RP.recipe_contents.registerSelectionData = (rootNode, adoption_func) ->
	sel = window.getSelection()
	anchorPath = RP.recipe_pages.getPathTo sel.anchorNode, rootNode
	focusPath = RP.recipe_pages.getPathTo sel.focusNode, rootNode
	adoption_func anchorPath, sel.anchorOffset, focusPath, sel.focusOffset

RP.recipe_contents.registerSelection = (event) ->
	text = window.getSelection().toString()
	rootNode = document.getElementById 'rp-html-content'
	RP.recipe_contents.registerSelectionData rootNode, (anchorPath, anchorOffset, focusPath, focusOffset) =>
		if anchorPath != focusPath || anchorOffset != focusOffset
			$('input.anchorPath').val anchorPath
			$('input.anchorOffset').val anchorOffset
			$('input.focusPath').val focusPath
			$('input.focusOffset').val focusOffset
			console.debug 'anchor path, offset: ' + anchorPath + ', ' + anchorOffset
			console.debug 'focus path, offset: ' + focusPath + ', ' + focusOffset

RP.recipe_contents.onclose = (dlog) ->
	document.removeEventListener "mouseup", RP.recipe_contents.registerSelection

# When a replacement tag is selected, arm the Submit button
RP.recipe_contents.onAdd = (evt) ->
	$('input.btn-success[value="Submit"').prop 'disabled', false

# When a previously selected replacement tag is removed, disarm the Submit button
RP.recipe_contents.onDelete = (evt) ->
	$('input.btn-success[value="Submit"').prop 'disabled', true

# When the dialog is first loaded, copy the content from the annotation form to the recipe form and the page
RP.recipe_contents.onload = (dlog) ->
	content_html = $('input#recipe_annotation_content').val()
	$('form.edit_recipe input#recipe_content').val content_html
	$('form.edit_recipe input.dialog-submit-button').prop 'disabled', false
	rootNode = document.getElementById 'rp-html-content'
	rootNode.innerHTML = content_html
	document.addEventListener "mouseup", RP.recipe_contents.registerSelection, false
	if $('input#trigger-parse')[0]
		$('input#trigger-parse').trigger 'click'
# $('form.annotate-recipe').trigger 'submit'
		# RP.submit.fire $('input#trigger-parse')[0] # submit the parsing of the designated (by parse_path) tree
#	$(dlog).on "click", '.submit-selection', (event) ->
#		# When submitting
#		# adopt_selection $(event.target).parents('div.recipe-fields')[0] # The enclosing fields set
#		event.preventDefault()
#	# When a selection occurs, load the path and offset inputs
#	document.onselectionchange = () =>
#		rootNode = document.getElementById 'rp-html-content'
#		RP.recipe_contents.registerSelectionData rootNode, (anchorPath, anchorOffset, focusPath, focusOffset) =>
#			$('input.anchorPath').val anchorPath
#			$('input.anchorOffset').val anchorOffset
#			$('input.focusPath').val focusPath
#			$('input.focusOffset').val focusOffset
#			console.debug 'anchor path, offset: ' + anchorPath + ', ' + anchorOffset
#			console.debug 'focus path, offset: ' + focusPath + ', ' + focusOffset

