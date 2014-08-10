RP.masonry = RP.masonry || {}

jQuery ->
	# RP.masonry.onload()

RP.masonry.onload = (selector='.masonry-container') ->
	# Initialize Masonry handling for list items
	$(selector).masonry
		columnWidth: $(selector).data('columnWidth') || 200,
		gutter: $(selector).data('gutterWidth') || 20,
		itemSelector: '.masonry-item'
