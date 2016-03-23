jQuery ->
	$('body').on 'click', 'a[href=#menuExpand]', (event) ->
		$('div.menu').toggleClass 'menuOpen'
		$('div.triggered-form').toggleClass 'menuOpen'
		$('ul.dropdown-menu li a').click (event) ->
			$('div.menu').toggleClass 'menuOpen'
			$('div.triggered-form').toggleClass 'menuOpen'
		event.preventDefault();

