jQuery ->
	$('body').on 'click', 'a.remove_fields', (event) ->
		$(this).prev('input[type=hidden]').val('1')
		$(this).closest('fieldset').hide()
		event.preventDefault()

	$('body').on 'click', 'a.add_fields', (event) ->
		time = new Date().getTime()
		regexp = new RegExp($(this).data('id'), 'g')
		newfields = $(this).data('fields').replace(regexp, time)
		$(this).before(newfields)
		event.preventDefault()

	$('body').on 'change', 'select.question-selector', (event) ->
		qid = this.value
		if $('input.question_id[value='+qid+']')[0]
			# Question already extant
		else
			qtext = $('option[value='+qid+']', this).text()
			adder = $('a.add_fields')[0]
			time = new Date().getTime()
			regexp = new RegExp($(adder).data('id'), 'g')
			newfields = $(adder).data('fields').replace(regexp, time)
			$(adder).before(newfields)
			newelmt = adder.previousSibling
			$('label.question-text', newelmt).text qtext
			$('input.question-id', newelmt).val qid
