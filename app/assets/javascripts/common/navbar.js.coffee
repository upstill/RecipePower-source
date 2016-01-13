jQuery ->
	$('body').on 'click', 'a[href=#menuExpand]', (event) ->
		$('ul.main-menu').toggleClass 'menuOpen'
		$('div.triggered-form').toggleClass 'menuOpen'
		$('ul.dropdown-menu li a').click (event) ->
			$('ul.main-menu').toggleClass 'menuOpen'
			$('div.triggered-form').toggleClass 'menuOpen'
		event.preventDefault();

