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

# Remove an item from the DOM according to masonry protocol
RP.masonry.removeItem = (item) ->
	if $(item).hasClass('masonry-item') && $(item.parentNode).hasClass 'js-masonry'
		$(item.parentNode).masonry 'remove', item
	else
		$(item).remove()

RP.masonry.appendItem = (item, container_selector) ->
	$(container_selector).append item
	if $(container_selector).hasClass 'js-masonry'
		masonry_selector = container_selector+'.js-masonry'
		$(masonry_selector).masonry 'appended', item
		# Any (hopefully few) pictures that are loaded from URL will resize the element
		# when they appear.
		$(item).on 'resize', (evt) ->
			$(masonry_selector).masonry()
		RP.rcp_list.onload $('div.collection-item',item)

RP.masonry.replaceItem = (item, replacement) ->
	if $(item).hasClass('masonry-item-contents') &&
	$(item.parentNode).hasClass('masonry-item') &&
	$(mitem = item.parentNode.parentNode).hasClass('js-masonry')
		$(item).replaceWith replacement
		$(mitem).masonry() # Do the layout again
		true