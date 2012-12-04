# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http:#jashkenas.github.com/coffee-script/
jQuery ->
	$("#tagstxt").tokenInput("/tags/match.json", 
		crossDomain: false,
		hintText: "Type tags and strings to look for",
		noResultsText: "No matching tag found; hit Enter to search with text",
		prePopulate: $("#collection_query_tokens").data("pre"),
		theme: "facebook",
		onAdd: queryChange,
		onDelete: queryChange,
		allowFreeTagging: true
	)

# Callback when token set changes: handle as any change to the query form
# nee tokenChangeCallback
queryChange = (hi, li) ->
	# Invalidate all lists
	# $(".rcplist_container").removeClass("current"); # Bust any cached collections
	# Notify the server of the change and update as needed
	form = $('form.query_form')[0]
	jQuery.ajax(
		type: "POST",
		url: form.action,
		data: $(form).serialize(),
		dataType: "html",
		success: (resp, succ, xhr) ->
			# Explicitly update the currently-open section
			active = $("#accordion").accordion("option", "active");
			if (active == 0) 
				# The response is just the index of the tab to hit
				$("#rcpquery_tabset").tabs('load', Number(resp));
			else if (active != null)
				# Reload the list for the currently-active panel, if any
				queryAccordionUpdatePanel($("#accordion").children().slice((2*active)+1));
	);

