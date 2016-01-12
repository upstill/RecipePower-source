jQuery ->
	$('body').on 'click', 'a[href=#menuExpand]', (event) ->
		$('ul.main-menu').toggleClass 'menuOpen'
		event.preventDefault();

