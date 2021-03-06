RP.scroll ||= {}

jQuery ->
	$('div.panel-button').on 'click', () ->
		if $(this).hasClass 'panel-scroller'
			$('body').panelSnap 'snapTo', 'next'
		else
			$('a.select-content.signup').trigger 'click'
	$(window).scroll () ->
		if ($(window).scrollTop() >= $(document).height() - $(window).height() - 10)
			if RP.scroll.selector
				$(RP.scroll.selector).triggerHandler "rp_scroll_more"
				RP.scroll.set_handler()

RP.scroll.set_handler = (selector, fcn) ->
	selector ||= RP.scroll.selector
	$(selector).off 'rp_scroll_more'
	if fcn
		RP.scroll.selector = selector
		$(selector).on 'rp_scroll_more', fcn
	else
		RP.scroll.selector = null
