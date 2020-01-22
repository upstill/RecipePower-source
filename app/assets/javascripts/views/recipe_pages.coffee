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
	xpathResult = doc.evaluate '//.', doc.firstChild, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null

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
			return toParent+element.tagName+'['+(ix+1)+']';
		if sibling.nodeType == 1 && sibling.tagName == element.tagName
			ix++

RP.recipe_pages.onload = (dlog) ->
	$(dlog).on "click", '.edit-recipe', (event) ->
		$('.listing-item', dlog).removeClass('visible').addClass('hidden')
		$('.editing-item', dlog).removeClass('hidden').addClass('visible')
	$(dlog).on "click", '.copy-selection', (event) ->
		sel = window.getSelection()
		event.preventDefault()
		if sel.anchorNode && sel.focusNode && sel.anchorNode != sel.focusNode
			rootNode = document.getElementById 'rp_recipe_content'
			rootPath = 'id("rp_recipe_content")'
			fieldsNode = $(event.target).parents('div.recipe-fields')[0] # The enclosing fields set
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
		x=2 # Extract copy!! /html/body/div[4]/div[2]/div/div/div[1]/div/h2[3]
