RP.edit_referent = RP.edit_referent || {}

RP.edit_referent.onopen = (dlog) ->
	RP.edit_referent.check_removal()
	# Arm the removal link
	$(dlog).on 'click', '.remove_fields', (event) ->
		$(this).prev('input[type=hidden]').val('1')
		$(this).closest('tr.expression_fields').hide()
		RP.edit_referent.check_removal()
		event.preventDefault()

# Callback for the selection of a new tag for an expression
RP.edit_referent.add_expression = (token_input, li) ->
	# hi = { id: $(token_input)[0].value, name: $(token_input)[0].value }
	# hi.id is the tag id; hi.data is the string
	that = $('.add_fields') # The add-fields element carries the data for the new stuff
	time = new Date().getTime()
	# Replace the 'id' with a random timestamp
	regexp = new RegExp $(that).data('id'), 'g'
	newfields = $(that).data('fields').replace regexp, time

	# Insert the tag
	regexp = new RegExp "\\[\\w+ \\d+\\]"
	tagname = li.name.replace regexp, ''
	regexp = new RegExp "\\*\\*no tag\\*\\*", 'g'
	newfields = newfields.replace regexp, tagname

	# Insert the tag id
	regexp = new RegExp "type=.hidden."
	tagid = li.id || "\'"+li.name+"\'"
	valstr = "type=\"hidden\" value=\""+tagid+"\""
	newfields = newfields.replace regexp, valstr

	other = $('tr')
	$(other).last().after newfields
	RP.edit_referent.check_removal() # Arm or disarm the Remove link

	# Finally, clear the tag from the "Add Expression" box
	$('#referent_add_expression').tokenInput "clear"

# Set the state of the Remove buttons so the last expression can't be removed
RP.edit_referent.check_removal = ->
	if $('table#expressions_table input.delete-expression[value="false"]').length > 1
		$('a.remove-allowed').show()
		$('span.remove-not-allowed').hide()
	else
		$('a.remove-allowed').hide()
		$('span.remove-not-allowed').show()


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
