RP.querify = RP.querify || {}

jQuery ->
	RP.querify.broadcast()

###
The querify module handles control hits by modifying a query according to the control's
values and submitting the result.
A querify element has two data attributes: the request path, and the params to be expressed
in the query. When the querify element is hit with params, they not only go into the request, but
modify the standing params.
###

# When a querify element is loaded, first order of business is to execute its request
RP.querify.onload = (event) ->
	RP.querify.hit event.target

# Hit a querify item with some revised parameters
RP.querify.hit = (qi, params) ->
	if qi
		path = $(qi).data 'path'
		if query = $(qi).data 'query'
			if params
				for attrname,attrvalue of params
					query[attrname] = params[attrname]
		else
			query = params
		if query
			$(qi).data 'query', query
			request = RP.build_request path, query
		else
			request = path
		RP.submit.submit_and_process request, $(qi).data('method')

# When an element gets hit that's enclosed by a querify target, hit it with the params
RP.querify.onclick = (event) ->
	elmt = event.target
	RP.querify.hit RP.findEnclosingByClass('querify-supe', elmt), $(elmt).data('querify')
	event.preventDefault()

# Broadcast a query change across the DOM, or only to children of the root
RP.querify.broadcast = (params, root) ->
	$('.querify-supe', root || document).each (ix) ->
		RP.querify.hit this, params
