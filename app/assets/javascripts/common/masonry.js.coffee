RP.masonry = RP.masonry || {}

jQuery ->

RP.masonry.onload = (containerselector) ->
	# Initialize Masonry handling for list items
	if containerselector && (containerelement = $(containerselector)[0])
		masonryelement = $('.js-masonry', containerelement)
	else
		masonryelement = $('.js-masonry')
	$(masonryelement).masonry
		columnWidth: $(masonryelement).data('columnWidth') || 200,
		gutter: $(masonryelement).data('gutterWidth') || 20,
		itemSelector: '.masonry-item'
	RP.stream.check()
