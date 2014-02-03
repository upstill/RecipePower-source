RP.messaging ||= {}

jQuery ->
	# Handle messages that come from outside the iframe, e.g. from an authentication window
	$.receiveMessage process_message
###
	if window.addEventListener
		addEventListener "message", process_message, false
	else
		attachEvent "onmessage", process_message
###

# Function for cracking param string
ptq = (q) ->
	# parse the message */
	# semicolons are nonstandard but we accept them */
	x = q.replace(/;/g, '&').split '&'
	# q changes from string version of query to object */
	q={}
	for s, i in x
		t = s.split '=', 2
		name = unescape t[0]
		if t.length > 1
			q[name] = unescape t[1]
		else
			q[name] = true
	q

process_message = (evt) ->
	dt = ptq evt.data
	if fcn = RP.named_function "RP."+dt.call
		fcn dt
