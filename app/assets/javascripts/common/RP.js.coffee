# Establish RecipePower name space and define widely-used utility functionality
window.RP = window.RP || {}

# Formerly genericHandling
# Post any errors or notifications from a JSON response
# data.error gives error message
# data.notice gives non-alarming informational message
RP.notify = (data, preface) ->
	if data.error
		RP.postError preface+data.error
	else if data.notice 
		RP.postNotice data.notice

RP.postError = (str) ->
	if str && (str.length > 0) 
		$('#container').data "errorPost", str

RP.postNotice = (str) ->
	if str && (str.length > 0)
		$('#container').data "noticePost", str
#		jNotify str, 
#			HorizontalPosition: 'center', 
#			VerticalPosition: 'top'

# Respond to the preview-recipe button by opening a popup loaded with its URL.
#   If the popup gets blocked, return true so that the recipe is opened in a new
#   window/tab.
#   In either case, notify the server of the opening so it can touch the recipe
RP.servePopup = () -> 
	regexp = new RegExp "popup", "g"
	rcpid = this.getAttribute('id').replace regexp, ""
	RP.rcp_list.touch_recipe rcpid
	# Now for the main event: open the popup window if possible
	linkURL = this.getAttribute 'href'
	popUp = window.open linkURL, 'popup', 'width=600, height=300, scrollbars, resizable'
	if !popUp # || (typeof popUp === 'undefined')
		return true
	else
		popUp.focus()
		return false
