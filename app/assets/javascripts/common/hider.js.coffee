window.RP = window.RP || {}

jQuery ->
	RP.hide_all_empty()

RP.hide_all_empty = ->
	$('.hide-if-empty').addClass('hide-pending').each (ix, e) ->
		RP.hide_empty e
		true

RP.hide_empty = (elmt) ->
	elmt ||= this
	hidden = false
	if $(elmt).hasClass('hide-pending')
		all_hidden = true
		has_children = false
		$('.hide-if-empty', elmt).each (ix, e)->
			has_children = true
			all_hidden = RP.hide_empty e
		if !has_children
			all_hidden = (elmt.innerHTML == "") || (elmt.innerHTML.match("^%%.*%%$") != null)
		if hidden = all_hidden
			$(elmt).hide()
		else
			$(elmt).show()
		$(elmt).removeClass('hide-pending')
	else
		hidden = $(elmt).css('display') != 'none'
	hidden
