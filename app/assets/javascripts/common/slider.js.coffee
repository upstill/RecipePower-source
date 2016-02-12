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
	# Enable swiping...
	$('div.slider').swipe
		# Generic swipe handler for all directions
		swipeLeft: (event, direction, distance, duration, fingerCount, fingerData) ->
			console.log "You swiped left"
		,
		swipeRight: (event, direction, distance, duration, fingerCount, fingerData) ->
			console.log "You swiped right"
		,
		swipeStatus: (event, phase, direction, distance, duration, fingerCount, fingerData) ->
			console.log "Swiping " + phase + " " + direction + " " + distance
			parent = $(this)[0]
			winrect = parent.getBoundingClientRect()
			trackitem = $('.track', parent)[0]
			trackrect = trackitem.getBoundingClientRect()
			if phase == 'start'
				# Initialize locations and bounds
				$(trackitem).data 'startpos', trackrect.left
			else if phase == 'move'
				startpos = $(trackitem).data 'startpos'
				prevmove = trackrect.left - startpos # How much we've moved prior
				if direction == 'left'
					distance = -distance
					relmove = distance - prevmove
					relmove = Math.max (winrect.right-trackrect.right), relmove
					console.log "relmove is " + relmove
					slide_track trackitem, relmove
				else if direction == 'right'
					relmove = distance - prevmove
					relmove = Math.min (winrect.left-trackrect.left), relmove
					console.log "relmove is " + relmove
					slide_track trackitem, relmove
			else if phase == 'end'
				# We check for loading more items
				if (stream_trigger = $('.stream-trigger', parent)[0]) && (trackrect.right - winrect.right) < 500
					# Fire if the trigger is closer than 500 pixels to visibility
					RP.stream.fire stream_trigger
		,
		tap: (event, target) ->
			console.log "Tapped " + target
		,
		# Default is 75px, set to 0 for demo so any distance triggers swipe
		threshold: 0
	# $(button_elmt).hover RP.slider.hoverin, RP.slider.hoverout
	$(button_elmt).click RP.slider.click
	button_check button_elmt

RP.slider.click = (event) ->
	button_elmt = event.currentTarget
	parent = button_elmt.parentNode
	trackitem = $('.track', parent)[0]
	right_button = $('.right', parent)[0]
	left_button = $('.left', parent)[0]
	winrect = parent.getBoundingClientRect()
	if button_elmt == right_button
		cutoff = winrect.right
	else
		cutoff = winrect.left - (winrect.right - winrect.left)
	# Do a linear search for the item that overlaps the left side of the scrolling panel
	$('.slider-item', parent).each (index) ->
		itemrect = this.getBoundingClientRect()
		if itemrect.right > cutoff
			# slide_by left_button, winrect.left-itemrect.left
			$(trackitem).animate
				left: ("+=" + (winrect.left-itemrect.left)),
				->
					if button_elmt == right_button # Check for more content if scrolling left
						button_check button_elmt
			return false # Break the loop

RP.slider.bump = (button_elmt) ->
	slide_by button_elmt, 5

scroll_to = (parent, elmt) ->
	$('.track', parent).scrollTo elmt, 100,
		axis: 'x'

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

setScroll = (button_elmt) ->
	clearScroll()
	RP.slider.current = setInterval ->
		RP.slider.bump button_elmt
	, 20

clearScroll = ->
	if RP.slider.current
		clearTimeout RP.slider.current
		RP.slider.current = null

RP.slider.hoverin = (event) ->
	setScroll event.currentTarget

RP.slider.hoverout = (event) ->
	clearScroll()

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
