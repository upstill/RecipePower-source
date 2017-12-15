RP.card = RP.card || {}

jQuery ->
	$(document).on 'image:empty', 'div.card-item img.empty', (event) ->
		$(event.currentTarget).closest('.pic-box').hide()

# Force layout of the Masonry elements when the avatar gets resized (upon load)
RP.card.onload = (event) ->
	RP.masonry.onload event # Normal initializing of the Masonry
	elmt = event.target
	$('div.stamp', elmt).resize (event) ->
		$(elmt).masonry() # Embedded images will trigger a layout when loaded
