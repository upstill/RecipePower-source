# Support for loading-content beachball
# When an ajax request starts, add the beach-ball class
jQuery ->
	$("body").on
		ajaxStart: ->
			if elmt = $('div.ajax-loader')[0]
				parent = elmt.parentElement
				elmt.style.width = ($(window).width()-parent.offsetLeft).toString()+"px"
				elmt.style.height = ($(window).height()-parent.offsetTop).toString()+"px"
				$(elmt).addClass "loading" 
		ajaxStop: -> 
			$('div.ajax-loader').removeClass "loading"
