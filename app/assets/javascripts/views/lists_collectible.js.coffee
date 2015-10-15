# Handle the dialog for managing the lists holding an item
#
RP.lists_collectible = RP.lists_collectible || {}

me = () ->
	$('div.lists-collectible.dialog')

RP.lists_collectible.add_title = ->
	RP.tagger.add_title()
	lists_present = $('div.control-group.now-appearing ul.token-input-list li.token-input-token')[0]
	$('div.control-group.now-appearing').each (ix, item) ->
		if lists_present
			$('label', item).show()
		else
			$('label', item).hide()
	$('li.token-input-input-token input').trigger 'click'

# When dialog is loaded, activate its functionality
RP.lists_collectible.onload = (dlog) ->
	$(dlog).on 'click', '.selection-item', (event) ->
		data = $(event.target).data()
		$(data.to_selector).tokenInput 'add', { id: data.id, name: event.target.innerText}
