# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

RP.recipe_pages = RP.recipe_pages || {}

# Code adapted from https://stackoverflow.com/questions/7312730/using-xpath-to-restore-a-dom-range-in-javascript
RP.recipe_pages.serialize = (node) ->
	if (typeof XMLSerializer != "undefined")
		# Firefox, etc.
		(new XMLSerializer()).serializeToString node
	else if (node.xml)
		node.xml

RP.recipe_pages.parseXMLString = (xml) ->
	if (typeof DOMParser != "undefined")
		# Firefox, etc.
		dp = new DOMParser();
		dp.parseFromString xml, "application/xml"
	else if (typeof ActiveXObject != "undefined")
		# IE
		doc = XML.newDocument()
		doc.loadXML xml
		doc

RP.recipe_pages.submit_selection = () ->
	contentNode = document.getElementById 'rp_recipe_content'
	xmlString = RP.recipe_pages.serialize contentNode
	doc = RP.recipe_pages.parseXMLString xmlString

	# Get elements from document using XPath
	xpathResult = document.evaluate '//.', doc.firstChild, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null

	# Insert elements back into document (I used replace in order to show that the document is actually changed)
	contentNode.parentNode.replaceChild xpathResult.singleNodeValue.firstChild, contentNode

getPathTo = (element, relative_to) ->
	if element.nodeType == 3
		return getPathTo(element.parentNode, relative_to)
	if element == relative_to
		return '' # element.tagName;
	if element.id
		return 'id("'+element.id+'")';

	ix= 0;
	for sibling in element.parentNode.childNodes
		if sibling == element
			toParent = getPathTo element.parentNode, relative_to
			if toParent != ''
				toParent += '/'
			etag = element.tagName
			if ix > 0 # Don't specify an index of 1 (JS is happy with it, but not Nokogiri)
				etag += '['+(ix+1)+']'
			return toParent + etag
		if sibling.nodeType == 1 && sibling.tagName == element.tagName
			ix++

display_fields = (recipeFieldsElmt, itemClass) ->
	# Show all and only the fields of the given class (editing-item or listing-item)
	$('div.recipe-field', recipeFieldsElmt).removeClass 'visible'
	$('div.recipe-field', recipeFieldsElmt).addClass 'hidden'
	$(('div.' + itemClass), recipeFieldsElmt).removeClass 'hidden'
	$(('div.' + itemClass), recipeFieldsElmt).addClass 'visible'

edit_field = (recipeFieldsElmt) ->
	$('div.recipe-fields').each (index, fe) ->
		# Copy the edited title to the display title
		ttl = $('.editing-item.title input', fe)[0].value
		if ttl == ''
			ttl = 'Recipe needs a title!'
		$('.listing-item.title h3', fe).text ttl
		# Hide the editing fields
		display_fields fe, 'listing-item'
	display_fields recipeFieldsElmt, 'editing-item'
	set_selection $('input.anchorPath', recipeFieldsElmt)[0].value, $('input.focusPath', recipeFieldsElmt)[0].value

adopt_selection = (fieldsNode) ->
	sel = window.getSelection()
	if sel.anchorNode && sel.focusNode && sel.anchorNode != sel.focusNode
		rootNode = document.getElementById 'rp_recipe_content'
		rootPath = 'id("rp_recipe_content")'
		anchorNode = sel.anchorNode
		focusNode = sel.focusNode
		if $(anchorNode).parents('div#rp_recipe_content').length != 1 || $(focusNode).parents('div#rp_recipe_content').length != 1
			alert "You need to select viable content for the recipe"
			return
		anchorOffset = sel.anchorOffset
		anchorPath = getPathTo anchorNode, rootNode
		$('input.anchorPath', fieldsNode)[0].value = anchorPath
		a2 = document.evaluate(anchorPath, rootNode, null, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue # This should be anchorNode
		focusOffset = sel.focusOffset
		focusPath = getPathTo focusNode, rootNode
		$('input.focusPath', fieldsNode)[0].value = focusPath
		f2 = document.evaluate(focusPath, rootNode, null, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue # This should be focusNode
	else
		alert "Select the body of this recipe in the page before grabbing it."

set_selection = (anchorPath, focusPath) ->
	if anchorPath && (anchorPath != '') && focusPath && (focusPath != '')
		rootNode = document.getElementById 'rp_recipe_content'
		anchorNode = document.evaluate(anchorPath, rootNode, null, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue # This should be anchorNode
		focusNode = document.evaluate(focusPath, rootNode, null, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue # This should be anchorNode
		range = document.createRange()
		range.setStartBefore anchorNode
		range.setEndAfter focusNode
		selection = window.getSelection()
		selection.removeAllRanges()
		selection.addRange range

RP.recipe_pages.onload = (dlog) ->
	$(dlog).on 'click', '.add_fields', (event) ->
		# Initialize a recipe by giving it a bogus, but unique, ID
		time = new Date().getTime()
		regexp = new RegExp($(this).data('id'), 'g')
		row = $(this).parents('div.row')[0]
		new_field = $(row).before($(this).data('fields').replace(regexp, time))
		new_field = $('div.recipe-fields').last()[0]
		edit_field new_field # Edit the newly-created fields
		adopt_selection new_field
		# TODO: grab selection, if any
		event.preventDefault()
	$(dlog).on "click", '.edit-recipe', (event) ->
		edit_field $(event.target).parents('div.recipe-fields')[0]  # The enclosing fields set
		event.preventDefault()
	$(dlog).on "click", '.copy-selection', (event) ->
		adopt_selection $(event.target).parents('div.recipe-fields')[0] # The enclosing fields set
		event.preventDefault()
