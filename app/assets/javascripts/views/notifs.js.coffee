RP.notifs ||= { }

jQuery ->
	$('a.notification-ack').on 'click', (event) ->
		$(event.currentTarget).closest('div.notification').hide()
		if $('div.notifs div.notification').length == 1 # This is the last notification extant
			$('div.notifs').hide()
	$('div.notification', document).on 'remove', (event) ->
		if $('div.notifs div.notification').length == 1 # This is the last notification extant
			$('div.notifs').hide()
