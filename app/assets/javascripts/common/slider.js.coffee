RP.slider ||= {}

jQuery ->
	$(document).on 'mouseenter', 'div.slider-item', (event) ->
		console.log "entering item of class " + event.target.attributes.class
		elmt = $(event.target).closest 'div.slider-item'
		if $('div.slider-right', elmt).hasClass 'pop-cardlet'
			$('div.slider-right', elmt).fadeIn()
	$(document).on 'mouseleave', 'div.slider-item', (event) ->
		console.log "leaving item of class " + event.target.attributes.class
		elmt = $(event.target).closest 'div.slider-item'
		if $('div.slider-right', elmt).hasClass 'pop-cardlet'
			$('div.slider-right', elmt).fadeOut()
	$(document).on 'image:empty', 'div.slider-pic img.empty', (event) ->
		enclosure = $(event.currentTarget).closest 'div.slider-item'
		$('div.slider-left', enclosure).hide()
		$('div.slider-right', enclosure).removeClass('pop-cardlet').addClass 'vis-cardlet'
		$(enclosure).addClass 'nopic'

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
	slide_track track_item, incr
	if incr < 0
		button_check button_elmt

slide_track = (track_item, incr) ->
	if incr != 0
		place = parseInt $(track_item).css('left')
		$(track_item).css 'left', place+incr

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

RP.slider.startScroll = (tracker) ->
	if RP.slider.intvl
		clearInterval RP.slider.intvl
		RP.slider.intvl = null
	if tracker && $(':first', tracker)[0]
		width = tracker.getBoundingClientRect().width
		RP.slider.intvl = setInterval ->
			if tracker.getBoundingClientRect().top < window.innerHeight && tracker.getBoundingClientRect().top > 0
				incr = -3
				leftmost = tracker.children[0]
				rightmost = tracker.children[tracker.children.length - 1]
				# Ensure we don't run past the end of the items by moving the first item to the end
				if rightmost.getBoundingClientRect().right < tracker.parentNode.getBoundingClientRect().right
					if tracker.children[1]
						incr += tracker.children[1].getBoundingClientRect().left - leftmost.getBoundingClientRect().left
					else
						incr += leftmost.getBoundingClientRect().width
					$(tracker).append $(leftmost).detach()
				else
					if tracker.getBoundingClientRect().left < -width
						incr += width
				slide_track tracker, incr
		, 20
