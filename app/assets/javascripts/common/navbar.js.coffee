jQuery ->
	$('body').on 'click', 'a[href=#menuExpand]', (event) ->
		$('.menu').toggleClass 'menuOpen'
		e.preventDefault();

