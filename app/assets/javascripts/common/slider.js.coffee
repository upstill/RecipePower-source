RP.slider ||= {}

jQuery ->

RP.slider.setup = (button_elmt) ->
	$(button_elmt).hover RP.slider.hoverin, RP.slider.hoverout
	$(button_elmt).click RP.slider.click
	button_check button_elmt

RP.slider.click = (event) ->
	button_elmt = event.currentTarget
	slide_by button_elmt, parseInt(button_elmt.parentNode.css "width")

RP.slider.bump = (button_elmt) ->
	slide_by button_elmt, 5

slide_by = (button_elmt, incr) ->
	if $(button_elmt).hasClass "right"
		incr = -incr
	track = $('.track', button_elmt.parentNode)[0]
	place = parseInt $(track).css('left')
	$(track).css 'left', place+incr
	button_check button_elmt

button_check = (button_elmt) ->
	if stream_trigger = $('.stream-trigger', button_elmt.parentNode)[0]
		button_rect = button_elmt.getBoundingClientRect()
		trigger_rect = stream_trigger.getBoundingClientRect()
		if button_rect && trigger_rect && (trigger_rect.left-button_rect.right) < 200
			RP.stream.fire stream_trigger

RP.slider.trigger_check = (trigger_elmt) ->
	parent = RP.findEnclosingByClass 'slider', trigger_elmt
	$('.right', parent).each (index) ->
		button_check this

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
