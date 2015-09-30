jQuery ->
	$(document).on 'image:empty', 'div.card-item img.empty', (event) ->
		$(event.currentTarget).closest('td').addClass 'empty'
