# Management of panes within a dialog
RP.pane_runner = RP.pane_runner || {}

notify_pane = (what, pane) ->
	console.log('Notifying pane ' + $(pane).attr('id') + ' to ' + what);
	mgrName = $(pane).attr('id').replace '-pane', ''
	if mgrName && (mgr = RP[mgrName])
		if mgr.notify
			mgr.notify what, pane
			console.log '...notified'
		else if (fcn = mgr[what] || mgr["on" + what])
			fcn pane
			console.log '...notified'

RP.pane_runner.deactivate_pane = ->
	$(this).removeClass 'active'
	notify_pane 'deactivate', this

RP.pane_runner.activate_pane = ->
	$(this).addClass 'active'
	notify_pane 'activate', this

RP.pane_runner.shown = (dlog) ->
	true

pane_selector = (input) ->
	'#'+$(input).data('pane') + '-pane'

RP.pane_runner.open = (dlog) ->
	# paneButtons identifies a set of radio buttons for selecting a pane
	if $('#paneButtons', dlog).length > 0
		$('#paneButtons :input', dlog).change ->
			newshown = pane_selector this
			$('div.pane.active').each RP.pane_runner.deactivate_pane
			$(newshown).each RP.pane_runner.activate_pane
		$('#paneButtons label.active input').each ->
			$(pane_selector this).each RP.pane_runner.activate_pane
	else
		# No buttons => activate the (presumably lone) pane
		$('div.pane', dlog).each RP.pane_runner.activate_pane
	false

# Take the message here and percolate it down to the panes
RP.pane_runner.notify = (what, dlog) ->
	console.log 'pane_runner notified to ' + what
	# If there's a pane_runner manager for the message, call it
	# Otherwise, percolate it down to each pane
	if !((fcn = RP.pane_runner[what] || RP.pane_runner['on' + what]) && fcn(dlog))
		$('div.pane', dlog).each ->
			notify_pane what, this
