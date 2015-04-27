RP.querify = RP.querify || {}

###
jQuery ->
	s = RP.build_request "http:/blah"
	s = RP.build_request "http:/blah", {}
	s = RP.build_request "http:/blah", { x: "y" }
	s = RP.build_request "http:/blah?x=z&z=2", { x: "y" }
	x=2

  The querify module handles control hits by modifying a query according to the control's
  values and submitting the result.

  There are three kinds of DOM elements that are in play here:
  1) elements which provide/modify data for a query, passing it to the nearest enclosing 'querify' element
  2) exec elements (class 'querify querify-exec') which receive modified data from child elements and submit it when changed
  3) supe elements (class 'querify querify-supe') which also receive modified data from children, but distribute it
  downward to exec elements and other supe elements.

  A querify element has two data attributes: the request path, and the params to be expressed
  in the query. (The path is irrelevant to a 'supe' element.)
  When a querify element is hit with params, its own parameters get modified by the incoming ones.
  An exec element then goes on to incorporate those params into the query and submit it.
  A supe element simply passes the (modified) params down to its chidren.
###

# When a querify element is loaded, first order of business is to execute its request
RP.querify.onload = (event) ->
	hit event.target

# Hit an element with new parameter values, i.e., broadcast to enclosing supe elmts 
RP.querify.propagate = (elmt, params) ->
	# Apply the parameters to the nearest enclosing supe node
	if $(elmt).hasClass 'querify-supe'
		supe = elmt
	else
		supe = $(elmt).closest '.querify-supe'
	if supe
		down supe, params
	
# An input element may be tagged to call this when its value changes, to
# propagate any new values up to the nearest enclosing querify node
RP.querify.onchange = (event) ->
	elmt = event.target
	param = { }
	param[elmt.name] = elmt.value
	RP.querify.propagate elmt, param
	event.preventDefault()

# When an element gets hit that's enclosed by a querify target, hit it with the params
RP.querify.onclick = (event) ->
	elmt = event.target
	param = { altClicked: event.altKey }
	param[elmt.name] = elmt.value
	RP.querify.propagate elmt, param
	event.preventDefault()

# Propagate the param(s) to the supe and all its descendants
down = (supe, params) ->
	if supe
		hit supe, params
		$('.querify', supe).each (ix, child) ->
			hit child, params

# Hit a querify item with some revised parameters
# 'querify-link' nodes get their href modified for later clicking
# 'querify-exec' nodes get executed immediately
hit = (elmt, params) ->
	# A link gets its href modified
	if $(elmt).hasClass 'querify-link'
		elmt.data 'href', RP.build_request(elmt.data('href'), params)
	# If the supe is also an exec node, fire it off
	if $(elmt).hasClass 'querify-exec'
		request = RP.build_request ($(elmt).data 'href'), params
		$(elmt).data 'href', request # Save for later
		RP.submit.submit_and_process request
