RP.notifications ||= {}

# Post a notification to the user, depending on what methods are available and a 
# stated preference. If 'how' isn't specified, it posts whichever is available, in this 
# order of preference:
# "flash" -- bootstrap-style notifications with close option (may have level appended after '-')
# "alert" -- bootstrap alert
# "popup" -- jNotify popup
RP.notifications.post = (msg, how) ->
	if msg && msg.length > 0

		# Handle 'how' that's like "flash-<level>"
		if how && how.match /^flash/
			level = how.replace("flash-","") || "alert"
			how = "flash"

		((how == "flash") && insert_flash(msg, level)) ||
		((how == "alert") && (bootbox_alert msg)) ||
		((how == "popup") && (jnotify_popup msg)) ||
		insert_flash(msg, "alert") ||
		bootbox_alert(msg) ||
		jnotify_popup(msg)

# Let the user know that something's happening during an ajax request
RP.notifications.wait = (msg) ->
	if elmt = $('div.ajax-loader')[0]
		parent = elmt.parentElement
		elmt.style.width = ($(window).width()-parent.offsetLeft).toString()+"px"
		elmt.style.height = ($(window).height()-parent.offsetTop).toString()+"px"
		$(elmt).addClass "loading"
	else
		bootbox_alert msg

# Finished with wait process (msg optional)
RP.notifications.done = (msg) ->
	$('div.ajax-loader').removeClass "loading"
	bootbox_alert()
	if msg
		RP.notifications.post msg

# Return HTML suitable for injecting into an empty window
RP.notifications.html = (msg) ->
	"<span style=\"text-align:center\"><strong>"+msg+"</strong></span>"

# Formerly genericHandling
# Post any errors or notifications from a JSON response
# data.error gives error message
# data.notice gives non-alarming informational message
RP.notifications.from_response = (data) ->
	RP.notifications.post data["flash-success"], "flash-success"
	RP.notifications.post data["flash-error"], "flash-error"
	RP.notifications.post data["flash-alert"], "flash-alert"
	RP.notifications.post data["flash-notice"], "flash-notice"
	RP.notifications.post data.alert, "alert"
	RP.notifications.post data.popup, "popup"

jnotify_popup = (msg) ->
	if available = (typeof jNotify != "undefined")
		jNotify msg, { HorizontalPosition: 'center', VerticalPosition: 'top', TimeShown: 2000 }
	available

# Post a flash notification into the 'div.flash_notifications' element
insert_flash = (message, level) ->
	if available = $('div.flash_notifications')[0]
		bootstrap_class = "alert-"+level
		html = "<div class=\"alert "+
			bootstrap_class+
			"	alert_block fade in\">
		      <button class=\"close\" data-dismiss=\"alert\">&#215;</button>"+
	    message+
	    "</div>"
		$('div.flash_notifications').replaceWith html
	return available

# Simple popup to notify the user of a process
bootbox_alert = (msg) ->
	if available = (typeof bootbox != "undefined")
		if msg && msg.length > 0
			bootbox.alert msg
		else
			$('div.bootbox .modal-footer button').click() # $('div.bootbox').modal('hide') # $('div.bootbox.modal').modal 'hide'
			$('div.modal-backdrop').remove()
	return available
