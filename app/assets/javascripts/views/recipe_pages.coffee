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

RP.recipe_pages.onload = (dlog) ->
	$(dlog).on "click", '.edit-recipe', (event) ->
		$('.listing_item', dlog).removeClass('visible').addClass('hidden')
		$('.editing_item', dlog).removeClass('hidden').addClass('visible')
	$(dlog).on "click", '.copy-selection', (event) ->
		x=2 # Extract copy!!
