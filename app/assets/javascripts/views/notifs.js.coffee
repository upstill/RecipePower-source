RP.notifs ||= { }

RP.notifs.onload = (event) ->
	notifs = event.target
	$('div.notifs-holder').on 'submit', "form", RP.submit.filter_submit
	$('a.notification-ack').on 'click', (event) ->
		$(event.currentTarget).closest('div.notification').hide()
		if $('div.notifs div.notification').length == 1 # This is the last notification extant
			$('div.notifs').hide()
	$('div.notification', document).on 'remove', (event) ->
		if $('div.notifs div.notification').length == 1 # This is the last notification extant
			$('div.notifs').hide()
	$('.select-content', document).click (event) ->
		enclosure_selector = 'div.modal-body,div.header-links'
		$(enclosure_selector).hide().find('div.flash_notifications').removeClass 'flash-target'
		if targetClass = $(event.target).data 'activate'
			$(enclosure_selector).filter('.'+targetClass).show().find('div.flash_notifications').addClass 'flash-target'
		if $(event.target).hasClass 'rollup'
			$(event.target).show()
			$('a.select-content.none').hide()
			$(enclosure_selector).closest('div.notifs').addClass 'collapsed'
		else
			$('a.select-content.none').show()
			window.scrollTo 0, 0
			$(enclosure_selector).closest('div.notifs').removeClass 'collapsed'
		event.preventDefault()
