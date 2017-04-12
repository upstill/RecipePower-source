RP.edit_user ||= {}

RP.edit_user.onopen = (dlog) ->
	RP.pic_picker.open dlog

RP.edit_user.shown = (dlog) ->
	RP.pic_picker.activate dlog

