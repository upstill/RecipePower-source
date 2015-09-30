jQuery ->
	$('body').on 'click', 'a.remove_fields', (event) ->
		$(this).next('input[type=hidden]').val('1')
		fields = $(this).closest('fieldset')
		$(fields).hide()
		qid = $('input.question-id', fields)[0].value
		menu = $('select.question-selector')
		$(menu).val 0
		$(menu).show()
		$('option[value='+qid+']', menu).show()
		# Modify the prompt according to whether there's a question already
		if $("fieldset:not([style='display: none;'])").length == 0
			label = "Pick a Question"
		else
			label = "Pick Another Question"
		$('option[value=0]', menu).text label
		event.preventDefault()

	$('body').on 'click', 'a.add_fields', (event) ->
		time = new Date().getTime()
		regexp = new RegExp($(this).data('id'), 'g')
		newfields = $(this).data('fields').replace(regexp, time)
		$(this).before(newfields)
		event.preventDefault()

	$('body').on 'change', 'select.question-selector', (event) ->
		menuid = this.value
		menuitem = $('option[value='+menuid+']', this)
		$(menuitem).hide()
		menutext = $(menuitem).text()
		if oitem = $('input.question-id[value='+menuid+']')[0]
			# Question already extant
			$(oitem).prev('input[type=hidden]').val('0')
			fieldset = $(oitem).closest('fieldset')[0]
			$(fieldset).show()
		else
			# $('option[value='+menuid+']', this).remove()
			adder = $('a.add_fields')[0]
			time = new Date().getTime()
			regexp = new RegExp($(adder).data('id'), 'g')
			newfields = $(adder).data('fields').replace(regexp, time)
			$(adder).before(newfields)
			fieldset = adder.previousSibling
			$('label.question-text', fieldset).text menutext
			$('input.question-id', fieldset).val menuid
		$('input.answer-text', fieldset).trigger "focus"
		$('.answer-text', fieldset).select()
		# Hide the menu if there are no more questions to be picked
		if $("option:not([style='display: none;'])", this).length == 1
			$(this).hide()
		else
			$('option[value=0]', this).text "Pick Another Question"
		this.value = 0 # $(this).val 0 # Reset the menu to the label

