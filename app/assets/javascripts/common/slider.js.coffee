RP.slider ||= {}

jQuery ->

RP.slider.setup = (button_elmt) ->
	$(button_elmt).hover RP.slider.hoverin, RP.slider.hoverout
	RP.slider.check_trigger button_elmt

RP.slider.bump = (button_elmt) ->
	track = $('.track', button_elmt.parentNode)[0]
	if $(button_elmt).hasClass "left"
		incr = 5
	else
		incr = -5
	place = parseInt $(track).css('left')
	$(track).css 'left', place+incr
	RP.slider.check_trigger button_elmt

RP.slider.check_trigger = (button_elmt) ->
	if stream_trigger = $('.stream-trigger', button_elmt.parentNode)[0]
		button_rect = button_elmt.getBoundingClientRect()
		trigger_rect = stream_trigger.getBoundingClientRect()
		if button_rect && trigger_rect && (trigger_rect.left-button_rect.right) < 200
			RP.stream.fire stream_trigger

RP.slider.hoverin = (event) ->
	button_elmt = event.currentTarget
	RP.slider.current = setInterval ->
		RP.slider.bump(button_elmt)
	, 20

RP.slider.hoverout = (event) ->
	button_elmt = event.currentTarget
	if RP.slider.current
		clearTimeout RP.slider.current
		RP.slider.current = null
