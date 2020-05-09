
RP.parsing = RP.parsing || {}

# Remove from the dom all children of the given node except ancestors of watch_for and any in the selection
RP.parsing.purgeChildren = (parent, except, selection) ->
	for child in parent.childNodes
		if (child instanceof Node) && !selection.containsNode(child) && (except.indexOf(child) < 0)
			parent.removeChild child

# Enumerate all nodes from the ancestor to the descendant, including the former but not the latter
RP.parsing.pathFromTo = (ancestor, descendant, collection = []) ->
	while descendant != ancestor
		descendant = descendant.parentNode
		collection.push descendant if collection.indexOf(descendant) < 0
	collection

# Extract the current selection in the minimal way, by eliminating:
# -- all children of all nodes up to and including the common ancestor that aren't touched by the selection
#			(i.e., they're either an ancestor of the anchor or focus, or they're included in the selection)
# -- all text before the anchor text offset (if the anchor is a text node)
# -- all text after the focus text offset (if the focus is a text mode)
RP.parsing.clearAroundSelection = () ->
	selection = document.getSelection()
	# ancestor = selection.commonAncestorContainer()
	ancestor = $('div.card-content')[0]
	anchor = selection.anchorNode
	focus = selection.focusNode
	to_preserve = RP.parsing.pathFromTo ancestor, anchor
	to_preserve = RP.parsing.pathFromTo ancestor, focus, to_preserve
	RP.parsing.purgeChildren node, to_preserve, selection for node in to_preserve

	
