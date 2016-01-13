jQuery ->
	$('body').on 'click', 'a[href=#menuExpand]', (event) ->
		$('ul.main-menu').toggleClass 'menuOpen'
		$('div.triggered-form').toggleClass 'menuOpen'
		event.preventDefault();

