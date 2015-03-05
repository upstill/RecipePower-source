RP.masonry = RP.masonry || {}

jQuery ->

# Handle items spewing to a masonry container (or not: non-masonry items are just silently appended)
# NB: includes a queuing mechanism so that each item is only appended after the prior one is done,
# but this appears to make no material difference: visually, they all seem to be loaded at once
RP.masonry.onload = (event) ->
	elmt = event.target
	# Initialize Masonry handling for list items
	$(elmt).masonry
		columnWidth: $(elmt).data('columnWidth') || 200,
		gutter: $(elmt).data('gutterWidth') || 20,
		itemSelector: '.masonry-item'
	$(elmt).masonry 'on', 'layoutComplete', ( msnryInstance, laidOutItems ) ->
		$(elmt).removeClass 'layout-pending'
		dequeue elmt

dequeue = (elmt) ->
	if !($(elmt).hasClass 'layout-pending') && (q = $(elmt).data('itemQ')) && (item = q.shift())
		$(elmt).data 'itemQ', q
		appendItemToMasonry item, elmt

enqueue = (item, masonry_selector) ->
	if $(masonry_selector).hasClass 'layout-pending'
		q = $(masonry_selector).data( 'itemQ') || []
		q.push item
		$(masonry_selector).data 'itemQ', q
	else
		appendItemToMasonry item, masonry_selector

appendItemToMasonry = (item, masonry_selector) ->
	$(masonry_selector).addClass 'layout-pending'
	$(masonry_selector).append item
	$(masonry_selector).masonry 'appended', item
	# Any (hopefully few) pictures that are loaded from URL will resize the element
	# when they appear.
	$(item).on 'resize', (evt) ->
		$(masonry_selector).masonry()
	RP.rcp_list.onload $('div.collection-item',item)

prependItemToMasonry = (item, masonry_selector) ->
	$(masonry_selector).addClass 'layout-pending'
	$(masonry_selector).prepend item
	$(masonry_selector).masonry 'prepended', item
	# Any (hopefully few) pictures that are loaded from URL will resize the element
	# when they appear.
	$(item).on 'resize', (evt) ->
		$(masonry_selector).masonry()
	RP.rcp_list.onload $('div.collection-item',item)
	RP.loadElmt item

RP.masonry.appendItem = (item, container_selector) ->
	if $(container_selector).hasClass 'js-masonry'
		masonry_selector = container_selector+'.js-masonry'
		enqueue item, masonry_selector # Put the item in line to be appended as soon as layout is complete
	else
		$(container_selector).append item

# Remove an item from the DOM according to masonry protocol
RP.masonry.removeItem = (item) ->
	if $(item).hasClass('masonry-item') && $(item.parentNode).hasClass 'js-masonry'
		$(item.parentNode).masonry 'remove', item
	else
		$(item).remove()

RP.masonry.prependItem = (item, container_selector) ->
	if $(container_selector).hasClass 'js-masonry'
		prependItemToMasonry item, container_selector
		# masonry_selector = container_selector+'.js-masonry'
		# enqueue item, masonry_selector # Put the item in line to be appended as soon as layout is complete
	else
		$(container_selector).prepend item
		RP.loadElmt item

RP.masonry.replaceItem = (item, replacement) ->
	if $(item).hasClass('masonry-item-contents') &&
	$(item.parentNode).hasClass('masonry-item') &&
	$(mitem = item.parentNode.parentNode).hasClass('js-masonry')
		$(item).replaceWith replacement
		$(mitem).masonry() # Do the layout again
		true