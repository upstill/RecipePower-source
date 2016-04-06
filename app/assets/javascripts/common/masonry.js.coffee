RP.masonry = RP.masonry || {}

jQuery ->

# Handle items spewing to a masonry container (or not: non-masonry items are just silently appended)
# NB: includes a queuing mechanism so that each item is only appended after the prior one is done,
# but this appears to make no material difference: visually, they all seem to be loaded at once
RP.masonry.onload = (event) ->
	elmt = event.target
	# Initialize Masonry handling for list items
	options = $(elmt).data('masonryOptions') || { }
	# Assert defaults for Masonry options
	# options.columnWidth ||= 80 # In fact, masonry will use the width of the first item for columnWidth
	options.gutter ||= 10
	options.itemSelector ||= '.masonry-item'
	$(elmt).masonry options
	$(elmt).masonry 'on', 'layoutComplete', ( msnryInstance, laidOutItems ) ->
		$(elmt).removeClass 'layout-pending'
		dequeue elmt
		if (!$(elmt).hasClass 'layout-pending') && (trigger = $('.stream-trigger', elmt)[0]) && (trigger.getBoundingClientRect().top > 0)
			$(trigger).trigger 'load'

dequeue = (elmt) ->
	if !($(elmt).hasClass 'layout-pending') && (q = $(elmt).data('itemQ')) && (item = q.shift())
		$(elmt).data 'itemQ', q
		appendItemToMasonry item, elmt

enqueue = (item, masonry_parent) ->
	if $(masonry_parent).hasClass 'layout-pending'
		q = $(masonry_parent).data( 'itemQ') || []
		q.push item
		$(masonry_parent).data 'itemQ', q
	else
		appendItemToMasonry item, masonry_parent

appendItemToMasonry = (item, masonry_parent) ->
	$(masonry_parent).addClass 'layout-pending'
	$(masonry_parent).append item
	$(masonry_parent).masonry 'appended', item
	# Any (hopefully few) pictures that are loaded from URL will resize the element
	# when they appear.
	$(item).on 'resize', (evt) ->
		$(masonry_parent).masonry()
	RP.rcp_list.onload $('div.collection-item',item)

prependItemToMasonry = (item, masonry_parent) ->
	$(masonry_parent).addClass 'layout-pending'
	$(masonry_parent).prepend item
	$(masonry_parent).masonry 'prepended', item
	# Any (hopefully few) pictures that are loaded from URL will resize the element
	# when they appear.
	$(item).on 'resize', (evt) ->
		$(masonry_parent).masonry()
	RP.rcp_list.onload $('div.collection-item',item)
	RP.loadElmt item

RP.masonry.appendItem = (item, parent) ->
	if $(parent).hasClass 'js-masonry'
		enqueue item, parent # Put the item in line to be appended as soon as layout is complete
		true
	else
		false

# Remove an item from the DOM according to masonry protocol
RP.masonry.removeItem = (item) ->
	if $(item).hasClass('masonry-item') && $(item.parentNode).hasClass 'js-masonry'
		$(item.parentNode).masonry 'remove', item
		true
	else
		false

RP.masonry.prependItem = (item, parent) ->
	if $(parent).hasClass 'js-masonry'
		# enqueue item, parent # Put the item in line to be appended as soon as layout is complete
		prependItemToMasonry item, parent
		true
	else
		false

RP.masonry.replaceItem = (item, replacement) ->
	if $(item).hasClass('masonry-item-contents') &&
	$(item.parentNode).hasClass('masonry-item') &&
	$(mitem = item.parentNode.parentNode).hasClass('js-masonry')
		$(item).replaceWith replacement
		$(mitem).masonry() # Do the layout again
		true
	else
		false
