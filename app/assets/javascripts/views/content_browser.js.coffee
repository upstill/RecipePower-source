RP.content_browser = RP.content_browser || {}

# Delete an element of the collection, assuming that the server approves
# We get back an id suitable for removing an element from the collection
# NB Since this may have been the selected node, we have to ensure that 
# there's a selection extant at the end.
# ALSO: must send using DELETE method
RP.content_browser.delete_element = (path) ->
	# Submit the delete
	# Get the ID of the deleted element via JSON
	# Decide what element to select next (next element at same level, otherwise
	# previous element regardless of level)
	# Notify server of new selection; response: new list
	# Replace list with response
	debugger

# Run a dialog to add an element to the collection browser. Upon success,
# We get called back with a new node to add to our children
RP.content_browser.add_element = (path) ->
	recipePowerGetAndRunJSON(path, "modal", "floating")
