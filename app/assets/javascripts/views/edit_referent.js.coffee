RP.edit_expressions = RP.edit_expressions || {}
RP.edit_referent = RP.edit_referent || {}
RP.edit_page_refs = RP.edit_page_refs || {}

RP.edit_page_refs.onopen = (pane) ->
	$(pane).on 'click', '#add_page_ref', (event) ->
		$("form input[name='authenticity_token']")[0].value
		x=2
	$(pane).on 'click', '.add_fields', (event) ->
		# Launch a query back to the server to initialize/fetch the page_ref
		that = $('a.add_fields', pane) # The add-fields element carries the data for the new stuff
		# Replace the 'id' with a random timestamp
		newfields = replace_field_globally $(that).data('fields'), $(that).data('id'), new Date().getTime()

		# Insert the tag
		url = replace_field $('input#referent_add_page_ref')[0].value, "\\[\\w+ \\d+\\]", ''
		newfields = replace_field_globally newfields, $(that).data('url'), url

		other = $('tr', pane)
		$(other).last().after newfields

		# Finally, clear the tag from the "Add Reference" box
		$('input#referent_add_page_ref')[0].value = ''

RP.edit_expressions.onopen = (dlog) ->
	RP.edit_expressions.check_removal()
	# Arm the removal link
	$(dlog).on 'click', '.remove_fields', (event) ->
		$(this).prev('input[type=hidden]').val('1')
		$(this).closest('tr.expression_fields').hide()
		RP.edit_expressions.check_removal()
		event.preventDefault()

replace_field = (source, pattern, replacement) ->
	regexp = new RegExp pattern
	source.replace regexp, replacement

replace_field_globally = (source, pattern, replacement) ->
	regexp = new RegExp pattern, 'g'
	source.replace regexp, replacement

# Callback for the selection of a new tag for an expression
RP.edit_expressions.add_expression = (token_input, li) ->
	# hi = { id: $(token_input)[0].value, name: $(token_input)[0].value }
	# hi.id is the tag id; hi.data is the string
	parent = $(token_input).parent()
	that = $('a.add_fields', parent) # The add-fields element carries the data for the new stuff
	newfields = $(that).data('fields')

	# Replace the expression id with a random timestamp
	newfields = replace_field_globally newfields, $(that).data('id'), new Date().getTime()

	# Insert the tag
	tagname = replace_field li.name, "\\[\\w+ \\d+\\]", '' # Elide whitespace
	newfields = replace_field_globally newfields, "\\*\\*no tag\\*\\*", tagname

	# Insert the tag id
	tagid = li.id || "\'"+li.name+"\'"
	newfields = replace_field newfields, "type=.hidden.", "type=\"hidden\" value=\""+tagid+"\""

	other = $('tr', parent)
	$(other).last().after newfields
	RP.edit_expressions.check_removal() # Arm or disarm the Remove link

	# Finally, clear the tag from the "Add Expression" box
	$('#referent_add_expression').tokenInput "clear"

# Set the state of the Remove buttons so the last expression can't be removed
RP.edit_expressions.check_removal = ->
	exprtbl = $('table#expressions_table')
	if $('input.delete-expression[value="false"]', exprtbl).length > 1
		$('a.remove-allowed', exprtbl).show()
		$('span.remove-not-allowed', exprtbl).hide()
	else
		$('a.remove-allowed', exprtbl).hide()
		$('span.remove-not-allowed', exprtbl).show()

# When dialog is loaded, activate its functionality
###
RP.edit_referent.onload = ->
	# Bind tokenInput to the text fields
	tagtype = $('#referent_parent_tokens').data "type"
	querystr = "/tags/match.json?tagtype="+tagtype

	$("#referent_add_expression").tokenInput querystr+"&untypedOK=1",
		crossDomain: false,
		noResultsText: "No existing tag found; hit Enter to make a new tag",
		hintText: "Type/select another tag to express this thing",
		theme: "facebook",
		tokenLimit: 1,
		onAdd: add_expression, # Respond to tag selection by adding expression and deleting tag
		preventDuplicates: true,
		allowFreeTagging: true # allowCustomEntry: true

	$("#referent_parent_tokens").tokenInput querystr,
		crossDomain: false,
		noResultsText: "No existing tag found; hit Enter to make a new tag",
		hintText: "Tags for things that come under this category",
		prePopulate: $("#referent_parent_tokens").data("pre"),
		theme: "facebook",
		preventDuplicates: true,
		allowFreeTagging: true # allowCustomEntry: true

	$("#referent_child_tokens").tokenInput querystr,
		crossDomain: false,
		noResultsText: "No existing tag found; hit Enter to make a new tag",
		hintText: "Categories that include this",
		prePopulate: $("#referent_child_tokens").data("pre"),
		theme: "facebook",
		preventDuplicates: true,
		allowFreeTagging: true # allowCustomEntry: true
###
