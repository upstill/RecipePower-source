# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

# Generic dialog management
RP.gleanings = RP.gleanings || {}

# Handle 'dialog-run' remote links
jQuery ->
	$(document).on 'change', 'select.select-string', (event) ->
		me = event.currentTarget
		target_selector = $(me).data 'target'
		$(target_selector).val $(me).val()
