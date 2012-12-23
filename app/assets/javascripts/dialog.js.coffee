manager_of = (dlog) ->
	# Look for a manager using the dialog's class name
	classList = $(dlog).attr('class').split /\s+/ 
	for mgr_name in classList
		if RP[mgr_name] 
			return RP[mgr_name]
	return null	

RP.dialog = RP.dialog || {}

RP.dialog.go = (path, how, where) ->
	recipePowerGetAndRunJSON path, how, where

RP.dialog.apply = (method, dlog) ->
	mgr = manager_of dlog
	if mgr && mgr[method]
		mgr[method](dlog)

RP.dialog.onclose = (dlog) ->
	RP.dialog.apply 'onclose', dlog

RP.dialog.onload = (dlog) ->
	RP.dialog.apply 'onload', dlog
