RP.navbar ||= {}

jQuery ->
	$('body').on 'click', 'a[href=#menuExpand]', (event) ->
		$('div.menu').toggleClass 'menuOpen'
		$('div.triggered-form').toggleClass 'menuOpen'
		$('ul.dropdown-menu li a').click (event) ->
			$('div.menu').toggleClass 'menuOpen'
			$('div.triggered-form').toggleClass 'menuOpen'
		event.preventDefault();

	$(document).click (e) ->
		# Handle clicks outside the list
		if( !$(e.target).is(".notification_list_cover") && !$(e.target).is(".notification_wrapper a") )
			if($(".notification_wrapper").hasClass("open") && !$(".notification_wrapper").hasClass("opened"))
				$(".notification_wrapper").addClass("opened");
			else if($(".notification_wrapper").hasClass("opened"))
				$(".notification_wrapper").removeClass("open").removeClass("opened");

	# Arm the dropdown menus
	$('ul.nav li.master-navtab div.dropdown').hover ->
		$(this).find('.dropdown-menu').stop(true, true).delay(200).fadeIn(500)
	, ->
		$(this).find('.dropdown-menu').stop(true, true).delay(200).fadeOut(500)

RP.navbar.toggleNotifications = (evt) ->
	$(evt.target).closest('.notification_wrapper').toggleClass 'open'
