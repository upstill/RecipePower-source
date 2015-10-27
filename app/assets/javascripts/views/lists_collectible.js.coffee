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

# When an item is added to the tokeninput
RP.lists_collectible.onAdd = (tokeninput) ->
	added = input_tokens().last()
	$('p', added).innerHTML = tokeninput.name
	if tokeninput.cssclass
		$(added).addClass tokeninput.cssclass

RP.lists_collectible.onDelete = (tokeninput) ->
	$('div.selection-list a#'+tokeninput.cssid).show()

RP.lists_collectible.onReady = (whatever) ->
	$('li.token-input-input-token input').trigger 'click'
	input_tokens().each (ix, item) ->
		tokeninput = $(item).data 'tokeninput'
		if tokeninput.cssclass
			$(item).addClass tokeninput.cssclass


# When dialog is loaded, activate its functionality
RP.lists_collectible.onload = (dlog) ->
	$(dlog).on 'click', '.selection-item', (event) ->
		data = $(event.target).data()
		$(data.to_selector).tokenInput 'add', data.tokeninput
		$(event.target).hide()
