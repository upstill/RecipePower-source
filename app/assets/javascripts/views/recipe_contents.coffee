# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

RP.recipe_contents ||= {}

RP.recipe_contents.registerSelectionData = (rootNode, adoption_func) ->
	sel = window.getSelection()
	if true # sel.anchorNode && sel.focusNode && sel.anchorNode != sel.focusNode
		rootPath = 'id("' + rootNode.id + '")'
		anchorNode = sel.anchorNode
		focusNode = sel.focusNode
#		if $(anchorNode).parents('div#rp-html-content').length != 1 || $(focusNode).parents('div#rp-html-content').length != 1
#			alert "You need to select viable content for the recipe"
#			return
		anchorOffset = sel.anchorOffset
		anchorPath = RP.recipe_pages.getPathTo anchorNode, rootNode
		# $('input.anchorPath', fieldsNode)[0].value = anchorPath
		# a2 = document.evaluate(anchorPath, rootNode, null, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue # This should be anchorNode
		focusOffset = sel.focusOffset
		focusPath = RP.recipe_pages.getPathTo focusNode, rootNode
		# $('input.focusPath', fieldsNode)[0].value = focusPath
		# f2 = document.evaluate(focusPath, rootNode, null, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue # This should be focusNode
		adoption_func anchorPath, anchorOffset, focusPath, focusOffset
	else
		alert "Select the body of this recipe in the page before grabbing it."

# When the dialog is first loaded, copy the content from the recipe form to the page
RP.recipe_contents.onload = (dlog) ->
	x=2
	$(dlog).on "click", '.submit-selection', (event) ->
		# adopt_selection $(event.target).parents('div.recipe-fields')[0] # The enclosing fields set
		event.preventDefault()
	# When a selection occurs, load the path and offset inputs, and copy the content from the recipe form to here
	document.onselectionchange = () =>
		rootNode = document.getElementById 'rp-html-content'
		RP.recipe_contents.registerSelectionData rootNode, (anchorPath, anchorOffset, focusPath, focusOffset) =>
			$('input.anchorPath').val anchorPath
			$('input.anchorOffset').val anchorOffset
			$('input.focusPath').val focusPath
			$('input.anchorPath').val focusOffset
			console.debug 'anchorPath: ' + anchorPath
			console.debug 'anchorOffset: ' + anchorOffset
			console.debug 'focusPath: ' + focusPath
			console.debug 'focusOffset: ' + focusOffset
			# $('input.anchorPath', fieldsNode)[0].value = anchorPath

