RP.access_links = RP.access_links || {}

RP.access_links.onload = (event) ->
	RP.submit.form_prep $('form', event.target)[0]
	RP.submit.form_prep $('form', event.target)[1]
