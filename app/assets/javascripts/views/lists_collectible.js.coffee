# Handle the dialog for managing the lists holding an item
#
RP.lists_collectible = RP.lists_collectible || {}

me = () ->
	$('div.lists-collectible.dialog')

token_input = () ->
	$('input#tagging_lists_tokens')

input_tokens = () ->
	$('ul.token-input-list li.token-input-token')

matching_tag = (tagspec) ->
	taglist = token_input().data 'taglist'
	for ts2 in taglist
		if ts2.id == tagspec.id
			return ts2
	null

RP.lists_collectible.onAdd = (tokeninput) ->
	dom_item = input_tokens().last()[0]
	if tokeninput.owner_name
		if tokeninput.status == 'my own' || tokeninput.status == 'my collected'
			$(dom_item).addClass 'owned'
		else if tokeninput.status == 'owned' || tokeninput.status == 'collected'
			$('p', dom_item)[0].innerHTML = tokeninput.name + ' (' + tokeninput.owner_name + ')'
			$(dom_item).addClass 'friends'

RP.lists_collectible.onDelete = (tokeninput) ->
	$('div.selection-list a').each (ix, listitem) ->
		if $(listitem).data('tokeninput').id == tokeninput.id # If it's in the selected list, hide it
			$(listitem).show()

RP.lists_collectible.onReady = (whatever) ->
	$('li.token-input-input-token input').trigger 'click'

# When dialog is loaded, activate its functionality
RP.lists_collectible.onload = (dlog) ->
	$(dlog).on 'click', '.selection-item', (event) ->
		data = $(event.target).data()
		$(data.to_selector).tokenInput 'add', data.tokeninput
		$(event.target).hide()
