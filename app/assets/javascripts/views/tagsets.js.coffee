# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
jQuery ->
	$('body').on 'click', 'a.remove_tag_selection', (event) ->
		# Get the enclosing set of fields for the value
		fields = $(this).closest('fieldset')
		# Set the destroy flag and hide the fields
		$('input.destroy', fields).val '1'
		$(fields).hide()
		# Get the value of the selection, for reference in the menu
		qid = $('input.tagset-id', fields)[0].value
		menu = $('select#tag-selection-menu')
		# Reset the menu to show the prompt, and show it, in case it's hidden
		$(menu).val 0
		$(menu).show()
		# Show the affiliated menu item
		$('option[value='+qid+']', menu).show()
		# Modify the prompt according to whether there's a question already
		if $("fieldset.tag-selection-field:not([style='display: none;'])").length == 0
			label = "Pick One"
		else
			label = "Pick Another"
		$('option[value=0]', menu).text label
		event.preventDefault()

	$('body').on 'change', 'select#tag-selection-menu', (event) ->
		menuid = this.value
		menuitem = $('option[value='+menuid+']', this)
		$(menuitem).hide()
		menutext = $(menuitem).text()
		if oitem = $('input.tagset-id[value='+menuid+']')[0]
			# Question already extant
			$(oitem).prev('input[type=hidden]').val('0')
			fieldset = $(oitem).closest('fieldset')[0]
			$(fieldset).show()
		else
			time = new Date().getTime()
			regexp = new RegExp($(this).data('id'), 'g')
			newfields = $(this).data('fields').replace(regexp, time).replace('%%tagset_title%%', menutext)
			$(this).after(newfields)
			fieldset = this.nextSibling
			$('input.tagset-id', fieldset).val menuid
			# Initialize and focus on tag selector
			RP.tagger.setup $('.token-input-field-pending', fieldset)[0]
			# $('label.question-text', fieldset).text menutext
			# $('input.question-id', fieldset).val menuid
		$("input[type='text']", fieldset).focus()
		# $('.answer-text', fieldset).select()
		# Hide the menu if there are no more questions to be picked
		if $("option:not([style='display: none;'])", this).length == 1
			$(this).hide()
		else
			$('option[value=0]', this).text "Pick Another"
		this.value = 0 # $(this).val 0 # Reset the menu to the label

