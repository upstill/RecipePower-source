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
