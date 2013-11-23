window.RP = window.RP || {}

jQuery ->
	$('.hide-if-empty').each (ix, e) ->
		RP.hide_empty e
		true

RP.hide_empty = (elmt) ->
	elmt ||= this
	all_hidden = true
	has_children = false
	$('.hide-if-empty', elmt).each (ix, e)->
		has_children = true
		all_hidden = RP.hide_empty e
	if !has_children
		all_hidden = (elmt.innerHTML == "") || (elmt.innerHTML.match("^%%.*%%$") != null)
	if all_hidden
		$(elmt).hide()
	else
		$(elmt).show()
	all_hidden
