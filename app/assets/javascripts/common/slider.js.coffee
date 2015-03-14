RP.slider ||= {}

jQuery ->

RP.slider.setup = (elmt) ->
	$(elmt).hover RP.slider.hoverin, RP.slider.hoverout

RP.slider.bump = (elmt) ->
		track = $('.track', elmt.parentNode)[0]
		if $(elmt).hasClass "left"
			incr = 5
		else
			incr = -5
		place = parseInt $(track).css('left')
		$(track).css 'left', place+incr

RP.slider.hoverin = (event) ->
	elmt = event.currentTarget
	RP.slider.current = setInterval ->
		RP.slider.bump(elmt)
	, 20

RP.slider.hoverout = (event) ->
	elmt = event.currentTarget
	if RP.slider.current
		clearTimeout RP.slider.current
		RP.slider.current = null
