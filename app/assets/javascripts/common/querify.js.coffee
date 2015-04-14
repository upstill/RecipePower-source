RP.querify = RP.querify || {}

jQuery ->
	s = RP.build_request "http:/blah"
	s = RP.build_request "http:/blah", {}
	s = RP.build_request "http:/blah", { x: "y" }
	s = RP.build_request "http:/blah?x=z&z=2", { x: "y" }
	x=2
###
      RP.querify.broadcast document # Ping all supe nodes to produce results

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
	RP.querify.hit event.target

# Hit a querify item with some revised parameters
RP.querify.hit = (qi, params) ->
	# Apply the parameters to the nearest enclosing supe node
	if $(qi).hasClass 'querify-supe'
		supe = qi
	else
		supe = $(qi).closest '.querify-supe'
	# Propagate the param(s) to all supe descendants
	$('.querify-supe', supe).each (ix, child) ->
		RP.querify.hit child, params
	# Propagate the param(s) to all link descendants
	$('.querify-link', supe).each (ix, child) ->
		child.href = RP.build_request child.href, params
	if $(supe).hasClass 'querify-exec'
		request = RP.build_request ($(supe).data 'querypath'), params
		$(supe).data 'querypath', request # Save for later
		RP.submit.submit_and_process request

# An input element may be tagged to call this when its value changes, to
# propagate any new values up to the nearest enclosing querify node
RP.querify.onchange = (event) ->
	elmt = event.target
	param = { }
	param[elmt.name] = elmt.value
	RP.querify.hit elmt, param
	event.preventDefault()

# When an element gets hit that's enclosed by a querify target, hit it with the params
RP.querify.onclick = (event) ->
	elmt = event.target
	param = { }
	param[elmt.name] = elmt.value
	RP.querify.hit elmt, param
	event.preventDefault()
