RP.masonry = RP.masonry || {}

jQuery ->

RP.masonry.onload = (event) ->
	elmt = event.target
	# Initialize Masonry handling for list items
	$(elmt).masonry
		columnWidth: $(elmt).data('columnWidth') || 200,
		gutter: $(elmt).data('gutterWidth') || 20,
		itemSelector: '.masonry-item'
	# RP.stream.check()
