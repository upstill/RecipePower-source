RP.content_browser = RP.content_browser || {}

RP.content_browser.onload = () ->
	$('.RcpBrowser').click ->
		if !$(this).hasClass("active")
			# Hide all children of currently-selected collection
			selected = $('.RcpBrowser.active')[0]
			toClose = selected
			while(toClose && elementLevel(toClose) >= elementLevel(this))
				toggleChildren toClose
				toClose = parentOf toClose
			# Deselect current selection
			$(selected).removeClass "active"
			
			$(this).addClass "active"
			toggleChildren this # Make all children visible
			data = $(this).data 'html'
			if(data)
				$('div.collection_list')[0].innerHTML = data
			# Now that the selection is settled, we can fetch the recipe list
			RP.collection.update { selected: @id }
		else
			RP.collection.update()
	
	$('.delete_element').bind('ajax:error', RP.content_browser.failed_deletion )

RP.content_browser.click_to_browser = (e) ->
	inside = null
	me = e.currentTarget
	elements = $('li.RcpBrowser')
	i=0
	while i < elements.length
		elem = elements[i]
		elemWidth = $(elem).width()
		elemHeight = $(elem).height()
		elemPosition = $(elem).offset()
		elemPosition2 = new Object
		elemPosition2.top = elemPosition.top + elemHeight
		elemPosition2.left = elemPosition.left + elemWidth
		if ((e.pageX > elemPosition.left && e.pageX < elemPosition2.left) && (e.pageY > elemPosition.top && e.pageY < elemPosition2.top)) 
			inside = elem
		i = i+1
	if inside
		me.style.display = "none"
		window.history.replaceState({ an: "object" }, 'Collection', '/collection');
		$(inside).click()

# The parent of an element is the first element with a level lower than the element
parentOf = (elmt) ->
	thisLevel = elementLevel elmt
	while(elmt = $(elmt).prev()[0])
		if(elementLevel(elmt) < thisLevel)
			break
	return elmt

# Check an ancestry relation.
# For the ancestor to be above the descendent, it must be the
# first predecessor of the descendant at its level
isAncestor = (ancestor, descendant) ->
	prior = descendant
	targetLevel = elementLevel ancestor
	while(elementLevel(prior) > targetLevel)
		prior = $(prior).prev()[0]
		if !prior
			return false
	prior == ancestor

elementLevel = (elmt) ->
	cn = elmt.className
	ix = cn.indexOf 'Level'
	if ix > 0
		cn.charAt ix+5
	else
		"0"

toggleChildren = (me) ->
	myLevel = elementLevel me
	while((me = $(me).next()[0]) && (elementLevel(me) > myLevel))
		$(me).toggle 200

RP.content_browser.failed_deletion = (evt, xhr, status, error) ->
	$('.notifications-panel').html xhr.responseText

# Delete an element of the collection, assuming that the server approves
# We get back an id suitable for removing an element from the collection
# NB Since this may have been the selected node, we have to ensure that 
# there's a selection extant at the end.
# ALSO: must send using DELETE method
RP.content_browser.delete_element = (path) ->
	# Submit the delete
	# Get the ID of the deleted element via JSON
	# Decide what element to select next (next element at same level, otherwise
	# previous element regardless of level)
	# Notify server of new selection; response: new list
	# Replace list with response
	active = $('.RcpBrowser.active')[0]
	sibclass = active.className.match(/Level(\d)/)[0]
	parent = active.parentNode
	toselect = active.nextElementSibling
	if !$(toselect).hasClass sibclass
		toselect = active.previousElementSibling
	active.parentNode.removeChild active
	$(toselect).addClass "active"
	# $('div.loader').addClass "loading" # show progress indicator
	jQuery.ajax
		type: "POST"
		url: path
		dataType: "html"
		beforeSend: (xhr) ->
			xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
		success: (resp, succ, xhr) ->
			# Explicitly update the collection list
			document.open()
			document.write resp
			document.close()
			RP.content_browser.onload()
		error: (jqXHR, textStatus, errorThrown) ->
			$('.notifications-panel').html jqXHR.responseText

# Handle adding a new entity into the collection:
# -- post the message in the response
# -- translate the 'entity' field of the response into a DOM entry
# -- insert it after the current selection if not already extant
# -- if not already selected, select it and update the list

RP.content_browser.div = RP.content_browser.div || $('<div></div>')
RP.content_browser.insert_or_select = (resp) ->
	entities = resp.entity
	if typeof entities == 'string'
		entities = [entities]
	for entity in entities
		RP.content_browser.div.html(entity)
		div = RP.content_browser.div[0]
		elmt = div.firstChild
		if existing = $('#'+elmt.id)[0]
			div.removeChild elmt
			elmt = existing
		if (parent_id = $(elmt).data("parent_id")) && (parent_elmt = $('#'+parent_id)[0])
			target = parent_elmt
		else
			target = $('.RcpBrowser.active')[0] # Default target: the first active node
		# The node to insert after is either the parent or the selected node
		if target.nextSibling
		  target.parentNode.insertBefore elmt, target.nextSibling
		else
			target.parentNode.appendChild elmt
	$('.RcpBrowser.active').removeClass "active"
	$(elmt).addClass "active"
	if target != elmt
		RP.collection.update { selected: elmt.id }

jQuery ->
	RP.content_browser.onload()
