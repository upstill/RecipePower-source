RP.slider ||= {}

jQuery ->

RP.slider.setup = (button_elmt) ->
	$(button_elmt).hover RP.slider.hoverin, RP.slider.hoverout
	$(button_elmt).click RP.slider.click
	button_check button_elmt

RP.slider.click = (event) ->
	button_elmt = event.currentTarget
	parent = button_elmt.parentNode
	right_button = $('.right', parent)[0]
	left_button = $('.left', parent)[0]
	if button_elmt == right_button
		bound = right_button.getBoundingClientRect().right+2
	else
		bound = left_button.getBoundingClientRect().left-2
	# Do a linear search for the item that overlaps the right side of the scrolling panel
	$('.slider-item', parent).each (index) ->
		itemrect = this.getBoundingClientRect()
		if itemrect.right > bound
			slide_by left_button, left_button.getBoundingClientRect().left-itemrect.left
			if RP.slider.current
				clearTimeout RP.slider.current
				RP.slider.current = null
			return false

RP.slider.bump = (button_elmt) ->
	slide_by button_elmt, 5

slide_by = (button_elmt, incr) ->
	parent = button_elmt.parentNode
	track_item = $('.track', parent)[0]
	track_rect = track_item.getBoundingClientRect()
	button_rect = button_elmt.getBoundingClientRect()
	if $(button_elmt).hasClass "right"
		incr = -Math.min incr, (track_rect.right - button_rect.right)
		if incr > 0 # Don't shift right, whatever you do
			return
	else
		incr = Math.min incr, (button_rect.left - track_rect.left)
	if incr != 0
		place = parseInt $(track_item).css('left')
		$(track_item).css 'left', place+incr
		if incr < 0
			button_check button_elmt

button_check = (button_elmt) ->
	parent = button_elmt.parentNode
	if (stream_trigger = $('.stream-trigger', parent)[0]) && (right_button = $('.right', parent)[0])
		button_rect = right_button.getBoundingClientRect()
		trigger_rect = stream_trigger.getBoundingClientRect()
		if trigger_rect.left < (button_rect.right+500)  # Fire if the trigger is closer than 500 pixels to visibility
			RP.stream.fire stream_trigger

RP.slider.trigger_check = (trigger_elmt) ->
	parent = RP.findEnclosingByClass 'slider', trigger_elmt
	$('.right', parent).each (index) ->
		button_check this

RP.slider.hoverin = (event) ->
	button_elmt = event.currentTarget
	RP.slider.current = setInterval ->
		RP.slider.bump button_elmt
	, 20

RP.slider.hoverout = (event) ->
	button_elmt = event.currentTarget
	if RP.slider.current
		clearTimeout RP.slider.current
		RP.slider.current = null
