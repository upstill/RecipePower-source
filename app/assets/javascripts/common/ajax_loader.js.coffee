# Support for loading-content beachball
# When an ajax request starts, add the beach-ball class
$("body").on
	ajaxStart: ->
		$(this).addClass "loading" 
	ajaxStop: -> 
		$(this).removeClass "loading"
