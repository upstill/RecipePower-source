# Support for applying tags

RP.reporting = RP.reporting || {}

# jQuery ->

# Report a click on a link back to the server using the 'report' data item
RP.reporting.report = (elmt) ->
	if report = $(elmt).data 'report'
		RP.submit.submit_and_process report, elmt